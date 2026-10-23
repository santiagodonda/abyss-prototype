extends Node2D


signal integrity_changed(
	new_integrity: float
)

signal hull_failed

signal hull_restored


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Network")

@export var hull_id: StringName = (
	&"hull_main"
)


@export_group("Integrity")

@export var max_integrity: float = 100.0

@export var starting_integrity: float = 100.0

@export var breach_threshold: float = 0.0

@export var post_repair_integrity: float = 60.0


@export_group("Breach")

@export var linked_breach_path: NodePath = (
	NodePath("../HullBreach")
)


@export_group("Debug")

@export var show_debug_label: bool = true


# =========================================================
# ESTADO
# =========================================================

var current_integrity: float = 100.0

var breach_triggered: bool = false


# =========================================================
# REFERENCIAS
# =========================================================

@onready var linked_breach = (
	get_node_or_null(
		linked_breach_path
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

	add_to_group(
		"hull_target"
	)


	add_to_group(
		"network_hull_point"
	)


	current_integrity = clamp(
		starting_integrity,
		0.0,
		max_integrity
	)


	if linked_breach == null:

		push_error(
			"HullIntegrityPoint: HullBreach no encontrado."
		)


	if show_debug_label:

		create_debug_label()


	update_debug_label()

	queue_redraw()


# =========================================================
# PROCESS
# =========================================================

func _process(
	_delta: float
):

	# -----------------------------------------------------
	# ONLINE:
	#
	# Sólo el Host puede cambiar integridad debido a
	# reparación de la brecha.
	# -----------------------------------------------------

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	# -----------------------------------------------------
	# SI LA BRECHA GENERADA POR ESTE PUNTO FUE REPARADA,
	# RECUPERAMOS PARTE DE LA INTEGRIDAD.
	# -----------------------------------------------------

	if not breach_triggered:
		return


	if linked_breach == null:
		return


	if not linked_breach.has_method(
		"is_repaired"
	):

		return


	if not linked_breach.is_repaired():
		return


	restore_after_breach_repair()


# =========================================================
# DAÑO
# =========================================================

func apply_damage(
	amount: float,
	_source: StringName = &"damage"
) -> bool:

	# -----------------------------------------------------
	# MULTIPLAYER:
	#
	# El Client nunca modifica HullIntegrity directamente.
	# -----------------------------------------------------

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return false


	if amount <= 0.0:
		return false


	if breach_triggered:
		return false


	current_integrity -= amount


	current_integrity = clamp(
		current_integrity,
		0.0,
		max_integrity
	)


	integrity_changed.emit(
		current_integrity
	)


	if current_integrity <= breach_threshold:

		trigger_hull_failure()


	update_debug_label()

	queue_redraw()


	return true


# =========================================================
# FALLA DEL CASCO
# =========================================================

func trigger_hull_failure():

	# -----------------------------------------------------
	# Sólo Host / Offline puede generar la falla real.
	# -----------------------------------------------------

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	if breach_triggered:
		return


	breach_triggered = true


	current_integrity = max(
		current_integrity,
		0.0
	)


	if linked_breach != null:

		if linked_breach.has_method(
			"trigger_breach"
		):

			linked_breach.trigger_breach()


	hull_failed.emit()


	update_debug_label()

	queue_redraw()


# =========================================================
# RESTAURAR DESPUÉS DE SOLDADURA
# =========================================================

func restore_after_breach_repair():

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	breach_triggered = false


	current_integrity = clamp(
		post_repair_integrity,
		breach_threshold + 1.0,
		max_integrity
	)


	integrity_changed.emit(
		current_integrity
	)


	hull_restored.emit()


	update_debug_label()

	queue_redraw()


# =========================================================
# NETWORK ID
# =========================================================

func get_network_hull_id() -> StringName:

	return hull_id


# =========================================================
# BUILD NETWORK STATE
# =========================================================

func build_network_state() -> Dictionary:

	return {
		"hull_id":
			str(
				hull_id
			),

		"integrity":
			current_integrity,

		"max_integrity":
			max_integrity,

		"breached":
			breach_triggered
	}


# =========================================================
# APPLY NETWORK STATE
# =========================================================

func apply_network_state(
	state: Dictionary
):

	# -----------------------------------------------------
	# El Host nunca acepta estado remoto de HullIntegrity.
	# -----------------------------------------------------

	if (
		NetworkManager.is_online()
		and NetworkManager.is_host()
	):

		return


	if state.has(
		"max_integrity"
	):

		max_integrity = max(
			float(
				state[
					"max_integrity"
				]
			),
			0.001
		)


	if state.has(
		"integrity"
	):

		current_integrity = clamp(
			float(
				state[
					"integrity"
				]
			),
			0.0,
			max_integrity
		)


	var network_breached: bool = bool(
		state.get(
			"breached",
			breach_triggered
		)
	)


	var breach_was_triggered: bool = (
		breach_triggered
	)


	breach_triggered = (
		network_breached
	)


	# -----------------------------------------------------
	# HOST DICE QUE LA BRECHA FUE GENERADA.
	#
	# Abrimos la representación local si todavía estaba
	# reparada.
	#
	# NO hacemos el camino inverso todavía.
	# Reparación multiplayer corresponde a Hull Authority B.
	# -----------------------------------------------------

	if (
		breach_triggered
		and not breach_was_triggered
	):

		ensure_linked_breach_open()


	integrity_changed.emit(
		current_integrity
	)


	update_debug_label()

	queue_redraw()


# =========================================================
# ASEGURAR BRECHA ABIERTA EN CLIENT
# =========================================================

func ensure_linked_breach_open():

	if linked_breach == null:
		return


	if not is_instance_valid(
		linked_breach
	):

		return


	if not linked_breach.has_method(
		"trigger_breach"
	):

		return


	if linked_breach.has_method(
		"is_repaired"
	):

		if not linked_breach.is_repaired():
			return


	linked_breach.trigger_breach()


# =========================================================
# CONSULTAS
# =========================================================

func get_integrity() -> float:

	return current_integrity


func get_integrity_ratio() -> float:

	if max_integrity <= 0.0:
		return 0.0


	return clamp(
		current_integrity
		/ max_integrity,
		0.0,
		1.0
	)


func is_breached() -> bool:

	return breach_triggered


func can_receive_damage() -> bool:

	return not breach_triggered


func get_state_text() -> String:

	if breach_triggered:

		return "BREACHED"


	var ratio: float = (
		get_integrity_ratio()
	)


	if ratio <= 0.25:
		return "CRITICAL"


	if ratio <= 0.50:
		return "DAMAGED"


	if ratio <= 0.75:
		return "WORN"


	return "INTACT"


# =========================================================
# QA / RESET CONTROLADO
# =========================================================

func reset_for_qa(
	integrity_value: float = 100.0
):

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	current_integrity = clamp(
		integrity_value,
		0.0,
		max_integrity
	)


	breach_triggered = false


	integrity_changed.emit(
		current_integrity
	)


	update_debug_label()

	queue_redraw()


# =========================================================
# LABEL
# =========================================================

func create_debug_label():

	debug_label = Label.new()


	debug_label.name = (
		"HullIntegrityDebugLabel"
	)


	debug_label.position = Vector2(
		-80,
		-55
	)


	debug_label.size = Vector2(
		160,
		45
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


# =========================================================
# ACTUALIZAR LABEL
# =========================================================

func update_debug_label():

	if debug_label == null:
		return


	debug_label.text = (
		"HULL "
		+ str(
			int(
				round(
					get_integrity_ratio()
					* 100.0
				)
			)
		)
		+ "%\n"
		+ get_state_text()
	)


# =========================================================
# VISUAL
# =========================================================

func _draw():

	var ratio: float = (
		get_integrity_ratio()
	)


	draw_rect(
		Rect2(
			-45,
			-8,
			90,
			16
		),
		Color(
			0.12,
			0.12,
			0.12,
			1.0
		)
	)


	draw_rect(
		Rect2(
			-43,
			-6,
			86.0 * ratio,
			12
		),
		Color(
			0.50,
			0.65,
			0.70,
			1.0
		)
	)
