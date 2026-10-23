extends CanvasLayer


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Layout")

@export var zone_position: Vector2 = Vector2(
	15.0,
	505.0
)

@export var zone_size: Vector2 = Vector2(
	225.0,
	195.0
)

@export var joystick_center_local: Vector2 = Vector2(
	110.0,
	100.0
)


@export_group("Joystick")

@export var base_radius: float = 72.0

@export var movement_radius: float = 58.0

@export var knob_radius: float = 30.0

@export_range(
	0.0,
	0.9,
	0.01
)
var deadzone: float = 0.15


@export_group("Mobile")

@export var mobile_scale: float = 1.45


# =========================================================
# TAMAÑOS EFECTIVOS
# =========================================================

var current_scale: float = 1.0

var effective_base_radius: float = 72.0

var effective_movement_radius: float = 58.0

var effective_knob_radius: float = 30.0

var effective_zone_size: Vector2 = Vector2(
	225.0,
	195.0
)


# =========================================================
# UI
# =========================================================

var cover_panel: ColorRect

var base_panel: Panel

var knob_panel: Panel

var move_label: Label


# =========================================================
# INPUT
# =========================================================

var active_touch_index: int = -1

var mouse_active: bool = false

var joystick_value: Vector2 = Vector2.ZERO


# =========================================================
# READY
# =========================================================

func _ready():

	layer = 30


	configure_device_scale()


	create_cover_panel()

	create_base()

	create_knob()

	create_label()


	reset_joystick()


	set_process_input(
		true
	)


# =========================================================
# ESCALA SEGÚN DISPOSITIVO
# =========================================================

func configure_device_scale():

	current_scale = 1.0


	if (
		OS.has_feature("mobile")
		or OS.get_name() == "Android"
		or OS.get_name() == "iOS"
	):

		current_scale = (
			mobile_scale
		)


	effective_base_radius = (
		base_radius
		* current_scale
	)


	effective_movement_radius = (
		movement_radius
		* current_scale
	)


	effective_knob_radius = (
		knob_radius
		* current_scale
	)


	# Agrandamos también la superficie táctil.
	#
	# El centro se mantiene prácticamente en el
	# mismo lugar para no invadir demasiado HUD.
	if current_scale > 1.0:

		effective_zone_size = Vector2(
			250.0,
			215.0
		)


	else:

		effective_zone_size = (
			zone_size
		)


# =========================================================
# PANEL QUE CUBRE D-PAD VIEJO
# =========================================================

func create_cover_panel():

	cover_panel = ColorRect.new()


	cover_panel.name = (
		"JoystickBackground"
	)


	cover_panel.position = (
		zone_position
	)


	cover_panel.size = (
		effective_zone_size
	)


	cover_panel.color = Color(
		0.03,
		0.03,
		0.03,
		0.88
	)


	cover_panel.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)


	add_child(
		cover_panel
	)


# =========================================================
# BASE
# =========================================================

func create_base():

	base_panel = Panel.new()


	base_panel.name = (
		"JoystickBase"
	)


	var diameter: float = (
		effective_base_radius
		* 2.0
	)


	base_panel.size = Vector2(
		diameter,
		diameter
	)


	base_panel.position = (
		get_joystick_center()
		- Vector2(
			effective_base_radius,
			effective_base_radius
		)
	)


	base_panel.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	var style := StyleBoxFlat.new()


	style.bg_color = Color(
		0.10,
		0.18,
		0.22,
		0.90
	)


	style.border_color = Color(
		0.35,
		0.65,
		0.75,
		0.90
	)


	style.border_width_left = 3

	style.border_width_right = 3

	style.border_width_top = 3

	style.border_width_bottom = 3


	var radius: int = int(
		effective_base_radius
	)


	style.corner_radius_top_left = radius

	style.corner_radius_top_right = radius

	style.corner_radius_bottom_left = radius

	style.corner_radius_bottom_right = radius


	base_panel.add_theme_stylebox_override(
		"panel",
		style
	)


	add_child(
		base_panel
	)


# =========================================================
# PALANCA
# =========================================================

func create_knob():

	knob_panel = Panel.new()


	knob_panel.name = (
		"JoystickKnob"
	)


	var diameter: float = (
		effective_knob_radius
		* 2.0
	)


	knob_panel.size = Vector2(
		diameter,
		diameter
	)


	knob_panel.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	var style := StyleBoxFlat.new()


	style.bg_color = Color(
		0.30,
		0.70,
		0.85,
		0.95
	)


	style.border_color = Color(
		0.75,
		0.90,
		0.95,
		1.0
	)


	style.border_width_left = 3

	style.border_width_right = 3

	style.border_width_top = 3

	style.border_width_bottom = 3


	var radius: int = int(
		effective_knob_radius
	)


	style.corner_radius_top_left = radius

	style.corner_radius_top_right = radius

	style.corner_radius_bottom_left = radius

	style.corner_radius_bottom_right = radius


	knob_panel.add_theme_stylebox_override(
		"panel",
		style
	)


	add_child(
		knob_panel
	)


# =========================================================
# LABEL
# =========================================================

func create_label():

	move_label = Label.new()


	move_label.name = (
		"MoveLabel"
	)


	move_label.text = (
		"MOVE"
	)


	move_label.position = Vector2(
		zone_position.x,
		zone_position.y + 5.0
	)


	move_label.size = Vector2(
		effective_zone_size.x,
		25.0
	)


	move_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	move_label.add_theme_font_size_override(
		"font_size",
		13
	)


	move_label.add_theme_constant_override(
		"outline_size",
		4
	)


	move_label.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)


	move_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	add_child(
		move_label
	)


# =========================================================
# INPUT
# =========================================================

func _input(
	event
):

	# =====================================================
	# TOUCH
	# =====================================================

	if event is InputEventScreenTouch:

		if event.pressed:

			if active_touch_index != -1:
				return


			if not is_inside_joystick_zone(
				event.position
			):

				return


			active_touch_index = (
				event.index
			)


			update_joystick_from_position(
				event.position
			)


			get_viewport().set_input_as_handled()


		else:

			if event.index != active_touch_index:
				return


			active_touch_index = -1


			reset_joystick()


			get_viewport().set_input_as_handled()


		return


	# =====================================================
	# TOUCH DRAG
	# =====================================================

	if event is InputEventScreenDrag:

		if event.index != active_touch_index:
			return


		update_joystick_from_position(
			event.position
		)


		get_viewport().set_input_as_handled()


		return


	# =====================================================
	# MOUSE
	# =====================================================

	if event is InputEventMouseButton:

		if event.button_index != MOUSE_BUTTON_LEFT:
			return


		if active_touch_index != -1:
			return


		if event.pressed:

			if not is_inside_joystick_zone(
				event.position
			):

				return


			mouse_active = true


			update_joystick_from_position(
				event.position
			)


			get_viewport().set_input_as_handled()


		else:

			if not mouse_active:
				return


			mouse_active = false


			reset_joystick()


			get_viewport().set_input_as_handled()


		return


	# =====================================================
	# MOUSE DRAG
	# =====================================================

	if event is InputEventMouseMotion:

		if not mouse_active:
			return


		update_joystick_from_position(
			event.position
		)


		get_viewport().set_input_as_handled()


# =========================================================
# ZONA
# =========================================================

func is_inside_joystick_zone(
	screen_position: Vector2
) -> bool:

	var zone_rect := Rect2(
		zone_position,
		effective_zone_size
	)


	return zone_rect.has_point(
		screen_position
	)


# =========================================================
# CENTRO
# =========================================================

func get_joystick_center() -> Vector2:

	var center: Vector2 = (
		zone_position
		+ joystick_center_local
	)


	# En móvil el joystick es más grande.
	#
	# Lo desplazamos apenas para mantenerlo
	# contenido dentro de la zona inferior.
	if current_scale > 1.0:

		center += Vector2(
			8.0,
			0.0
		)


	return center


# =========================================================
# ACTUALIZAR
# =========================================================

func update_joystick_from_position(
	screen_position: Vector2
):

	var center: Vector2 = (
		get_joystick_center()
	)


	var offset: Vector2 = (
		screen_position
		- center
	)


	# -----------------------------------------------------
	# LIMITAR RECORRIDO
	# -----------------------------------------------------

	if offset.length() > effective_movement_radius:

		offset = (
			offset.normalized()
			* effective_movement_radius
		)


	# -----------------------------------------------------
	# VECTOR NORMALIZADO
	# -----------------------------------------------------

	var raw_value: Vector2 = (
		offset
		/ effective_movement_radius
	)


	var magnitude: float = (
		raw_value.length()
	)


	# -----------------------------------------------------
	# DEADZONE
	# -----------------------------------------------------

	if magnitude <= deadzone:

		joystick_value = (
			Vector2.ZERO
		)


	else:

		var corrected_strength: float = (
			(
				magnitude
				- deadzone
			)
			/
			(
				1.0
				- deadzone
			)
		)


		corrected_strength = clamp(
			corrected_strength,
			0.0,
			1.0
		)


		joystick_value = (
			raw_value.normalized()
			* corrected_strength
		)


	update_knob_position(
		offset
	)


	apply_movement_actions()


# =========================================================
# MOVER KNOB
# =========================================================

func update_knob_position(
	offset: Vector2
):

	if knob_panel == null:
		return


	var center: Vector2 = (
		get_joystick_center()
	)


	knob_panel.position = (
		center
		+ offset
		- Vector2(
			effective_knob_radius,
			effective_knob_radius
		)
	)


# =========================================================
# APLICAR MOVIMIENTO
# =========================================================

func apply_movement_actions():

	release_joystick_actions()


	if joystick_value.x < -0.01:

		Input.action_press(
			"move_left",
			abs(
				joystick_value.x
			)
		)


	elif joystick_value.x > 0.01:

		Input.action_press(
			"move_right",
			abs(
				joystick_value.x
			)
		)


	if joystick_value.y < -0.01:

		Input.action_press(
			"move_up",
			abs(
				joystick_value.y
			)
		)


	elif joystick_value.y > 0.01:

		Input.action_press(
			"move_down",
			abs(
				joystick_value.y
			)
		)


# =========================================================
# RESET
# =========================================================

func reset_joystick():

	joystick_value = (
		Vector2.ZERO
	)


	release_joystick_actions()


	if knob_panel != null:

		var center: Vector2 = (
			get_joystick_center()
		)


		knob_panel.position = (
			center
			- Vector2(
				effective_knob_radius,
				effective_knob_radius
			)
		)


# =========================================================
# LIBERAR INPUT
# =========================================================

func release_joystick_actions():

	Input.action_release(
		"move_up"
	)

	Input.action_release(
		"move_down"
	)

	Input.action_release(
		"move_left"
	)

	Input.action_release(
		"move_right"
	)


# =========================================================
# CONSULTAS
# =========================================================

func get_input_vector() -> Vector2:

	return joystick_value


func is_active() -> bool:

	return (
		active_touch_index != -1
		or mouse_active
	)
