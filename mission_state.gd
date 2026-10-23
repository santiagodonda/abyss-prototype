extends Node


# =========================================================
# ESTADOS DE LA PARTIDA
# =========================================================

enum MissionStateType {
	RUNNING,
	SUCCESS,
	FAILED
}


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Debug")

@export var print_state_changes: bool = true


# =========================================================
# REFERENCIAS
# =========================================================

@onready var submarine_status = (
	get_node_or_null(
		"../SubmarineStatus"
	)
)


# =========================================================
# ESTADO
# =========================================================

var current_state: MissionStateType = (
	MissionStateType.RUNNING
)

var failure_reason: String = ""

var success_reason: String = ""


# =========================================================
# UI DERROTA
# =========================================================

var failure_canvas: CanvasLayer

var failure_background: ColorRect

var failure_title: Label

var failure_subtitle: Label

var restart_button: Button


# =========================================================
# UI VICTORIA
# =========================================================

var success_canvas: CanvasLayer

var success_background: ColorRect

var success_title: Label

var success_subtitle: Label

var success_restart_button: Button


# =========================================================
# READY
# =========================================================

func _ready():

	process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	create_failure_ui()

	create_success_ui()


	set_failure_ui_visible(
		false
	)


	set_success_ui_visible(
		false
	)


	if submarine_status == null:

		push_warning(
			"MissionState: SubmarineStatus no encontrado."
		)


# =========================================================
# AUTHORITY
# =========================================================

func has_mission_authority() -> bool:

	if not NetworkManager.is_online():
		return true


	return NetworkManager.is_host()


# =========================================================
# PROCESS
# =========================================================

func _process(
	_delta: float
):

	if current_state != MissionStateType.RUNNING:
		return


	if not has_mission_authority():
		return


	if submarine_status == null:
		return


	if not submarine_status.has_method(
		"is_lost"
	):
		return


	if submarine_status.is_lost():

		fail_mission(
			"SUBMARINE LOST"
		)


# =========================================================
# VICTORIA AUTORITATIVA
# =========================================================

func complete_mission(
	reason: String = "OBJECTIVE COMPLETE"
):

	if not has_mission_authority():
		return


	if current_state != MissionStateType.RUNNING:
		return


	apply_state_internal(
		MissionStateType.SUCCESS,
		"",
		reason,
		"AUTH"
	)


# =========================================================
# DERROTA AUTORITATIVA
# =========================================================

func fail_mission(
	reason: String
):

	if not has_mission_authority():
		return


	if current_state != MissionStateType.RUNNING:
		return


	apply_state_internal(
		MissionStateType.FAILED,
		reason,
		"",
		"AUTH"
	)


# =========================================================
# NETWORK SHADOW
# =========================================================

func apply_network_state(
	new_state_name: String,
	new_failure_reason: String,
	new_success_reason: String
) -> bool:

	if not NetworkManager.is_online():
		return false


	if NetworkManager.is_host():
		return false


	var parsed_state: int = (
		get_state_from_name(
			new_state_name
		)
	)


	if parsed_state < 0:
		return false


	apply_state_internal(
		parsed_state,
		new_failure_reason,
		new_success_reason,
		"NET"
	)


	return true


# =========================================================
# APPLY INTERNAL
# =========================================================

func apply_state_internal(
	new_state: MissionStateType,
	new_failure_reason: String,
	new_success_reason: String,
	source: String
):

	var old_state_name: String = (
		get_state_name()
	)


	var old_failure_reason: String = (
		failure_reason
	)


	var old_success_reason: String = (
		success_reason
	)


	current_state = new_state

	failure_reason = new_failure_reason

	success_reason = new_success_reason


	match current_state:

		MissionStateType.RUNNING:

			get_tree().paused = false


			set_failure_ui_visible(
				false
			)


			set_success_ui_visible(
				false
			)


		MissionStateType.SUCCESS:

			release_gameplay_inputs()

			update_success_text()


			set_failure_ui_visible(
				false
			)


			set_success_ui_visible(
				true
			)


			get_tree().paused = true


		MissionStateType.FAILED:

			release_gameplay_inputs()

			update_failure_text()


			set_success_ui_visible(
				false
			)


			set_failure_ui_visible(
				true
			)


			get_tree().paused = true


	var changed: bool = (
		old_state_name != get_state_name()
		or old_failure_reason != failure_reason
		or old_success_reason != success_reason
	)


	if (
		print_state_changes
		and changed
	):

		var reason_text: String = ""


		if current_state == MissionStateType.FAILED:

			reason_text = failure_reason


		elif current_state == MissionStateType.SUCCESS:

			reason_text = success_reason


		print(
			"[MISSION STATE][",
			source,
			"] ",
			old_state_name,
			" -> ",
			get_state_name(),
			(
				" | "
				+ reason_text
				if not reason_text.is_empty()
				else ""
			)
		)


# =========================================================
# STATE FROM NAME
# =========================================================

func get_state_from_name(
	state_name: String
) -> int:

	match state_name:

		"RUNNING":
			return MissionStateType.RUNNING

		"SUCCESS":
			return MissionStateType.SUCCESS

		"FAILED":
			return MissionStateType.FAILED


	return -1


# =========================================================
# LIBERAR INPUTS
# =========================================================

func release_gameplay_inputs():

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


	Input.action_release(
		"interact"
	)


# =========================================================
# UI DERROTA
# =========================================================

func create_failure_ui():

	failure_canvas = CanvasLayer.new()

	failure_canvas.name = (
		"FailureCanvas"
	)

	failure_canvas.layer = 100


	add_child(
		failure_canvas
	)


	failure_background = ColorRect.new()

	failure_background.name = (
		"FailureBackground"
	)

	failure_background.position = Vector2.ZERO

	failure_background.size = Vector2(
		1280,
		720
	)

	failure_background.color = Color(
		0.02,
		0.02,
		0.02,
		0.90
	)

	failure_background.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)


	failure_canvas.add_child(
		failure_background
	)


	failure_title = Label.new()

	failure_title.name = (
		"FailureTitle"
	)

	failure_title.text = (
		"SUBMARINE LOST"
	)

	failure_title.position = Vector2(
		340,
		210
	)

	failure_title.size = Vector2(
		600,
		70
	)

	failure_title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	failure_title.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	failure_title.add_theme_font_size_override(
		"font_size",
		42
	)

	failure_title.add_theme_constant_override(
		"outline_size",
		6
	)

	failure_title.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.25,
			0.20,
			1.0
		)
	)

	failure_title.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)

	failure_title.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	failure_canvas.add_child(
		failure_title
	)


	failure_subtitle = Label.new()

	failure_subtitle.name = (
		"FailureSubtitle"
	)

	failure_subtitle.text = (
		"MISSION FAILED"
	)

	failure_subtitle.position = Vector2(
		340,
		290
	)

	failure_subtitle.size = Vector2(
		600,
		90
	)

	failure_subtitle.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	failure_subtitle.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	failure_subtitle.add_theme_font_size_override(
		"font_size",
		24
	)

	failure_subtitle.add_theme_constant_override(
		"outline_size",
		4
	)

	failure_subtitle.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)

	failure_subtitle.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	failure_canvas.add_child(
		failure_subtitle
	)


	restart_button = Button.new()

	restart_button.name = (
		"RestartButton"
	)

	restart_button.text = (
		"RESTART"
	)

	restart_button.position = Vector2(
		490,
		420
	)

	restart_button.size = Vector2(
		300,
		90
	)

	restart_button.add_theme_font_size_override(
		"font_size",
		24
	)

	restart_button.focus_mode = (
		Control.FOCUS_NONE
	)

	restart_button.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	restart_button.pressed.connect(
		_on_restart_pressed
	)


	failure_canvas.add_child(
		restart_button
	)


# =========================================================
# UI VICTORIA
# =========================================================

func create_success_ui():

	success_canvas = CanvasLayer.new()

	success_canvas.name = (
		"SuccessCanvas"
	)

	success_canvas.layer = 101


	add_child(
		success_canvas
	)


	success_background = ColorRect.new()

	success_background.name = (
		"SuccessBackground"
	)

	success_background.position = Vector2.ZERO

	success_background.size = Vector2(
		1280,
		720
	)

	success_background.color = Color(
		0.02,
		0.04,
		0.04,
		0.90
	)

	success_background.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)


	success_canvas.add_child(
		success_background
	)


	success_title = Label.new()

	success_title.name = (
		"SuccessTitle"
	)

	success_title.text = (
		"MISSION COMPLETE"
	)

	success_title.position = Vector2(
		340,
		210
	)

	success_title.size = Vector2(
		600,
		70
	)

	success_title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	success_title.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	success_title.add_theme_font_size_override(
		"font_size",
		42
	)

	success_title.add_theme_constant_override(
		"outline_size",
		6
	)

	success_title.add_theme_color_override(
		"font_color",
		Color(
			0.35,
			0.95,
			0.55,
			1.0
		)
	)

	success_title.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)

	success_title.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	success_canvas.add_child(
		success_title
	)


	success_subtitle = Label.new()

	success_subtitle.name = (
		"SuccessSubtitle"
	)

	success_subtitle.text = (
		"OBJECTIVE COMPLETED"
	)

	success_subtitle.position = Vector2(
		340,
		290
	)

	success_subtitle.size = Vector2(
		600,
		90
	)

	success_subtitle.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	success_subtitle.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	success_subtitle.add_theme_font_size_override(
		"font_size",
		24
	)

	success_subtitle.add_theme_constant_override(
		"outline_size",
		4
	)

	success_subtitle.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)

	success_subtitle.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	success_canvas.add_child(
		success_subtitle
	)


	success_restart_button = Button.new()

	success_restart_button.name = (
		"SuccessRestartButton"
	)

	success_restart_button.text = (
		"RESTART"
	)

	success_restart_button.position = Vector2(
		490,
		420
	)

	success_restart_button.size = Vector2(
		300,
		90
	)

	success_restart_button.add_theme_font_size_override(
		"font_size",
		24
	)

	success_restart_button.focus_mode = (
		Control.FOCUS_NONE
	)

	success_restart_button.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	success_restart_button.pressed.connect(
		_on_restart_pressed
	)


	success_canvas.add_child(
		success_restart_button
	)


# =========================================================
# TEXTO DERROTA
# =========================================================

func update_failure_text():

	if failure_title == null:
		return


	if failure_subtitle == null:
		return


	failure_title.text = (
		failure_reason
	)


	failure_subtitle.text = (
		"MISSION FAILED\n"
		+ "THE SUBMARINE COULD NOT BE RECOVERED"
	)


# =========================================================
# TEXTO VICTORIA
# =========================================================

func update_success_text():

	if success_title == null:
		return


	if success_subtitle == null:
		return


	success_title.text = (
		"MISSION COMPLETE"
	)


	success_subtitle.text = (
		success_reason
		+ "\n"
		+ "THE OBJECTIVE WAS COMPLETED"
	)


# =========================================================
# VISIBILIDAD
# =========================================================

func set_failure_ui_visible(
	value: bool
):

	if failure_canvas == null:
		return


	failure_canvas.visible = value


func set_success_ui_visible(
	value: bool
):

	if success_canvas == null:
		return


	success_canvas.visible = value


# =========================================================
# RESTART
# =========================================================

func _on_restart_pressed():

	release_gameplay_inputs()


	NetworkManager.request_game_restart()


# =========================================================
# RESET QA
# =========================================================

func reset_for_qa():

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	get_tree().paused = false


	current_state = (
		MissionStateType.RUNNING
	)


	failure_reason = ""

	success_reason = ""


	set_failure_ui_visible(
		false
	)


	set_success_ui_visible(
		false
	)


# =========================================================
# CONSULTAS
# =========================================================

func get_state_name() -> String:

	match current_state:

		MissionStateType.RUNNING:
			return "RUNNING"

		MissionStateType.SUCCESS:
			return "SUCCESS"

		MissionStateType.FAILED:
			return "FAILED"


	return "UNKNOWN"


func is_running() -> bool:

	return (
		current_state
		== MissionStateType.RUNNING
	)


func is_success() -> bool:

	return (
		current_state
		== MissionStateType.SUCCESS
	)


func is_failed() -> bool:

	return (
		current_state
		== MissionStateType.FAILED
	)


func get_failure_reason() -> String:

	return failure_reason


func get_success_reason() -> String:

	return success_reason


func is_failure_ui_visible() -> bool:

	if failure_canvas == null:
		return false


	return failure_canvas.visible


func is_success_ui_visible() -> bool:

	if success_canvas == null:
		return false


	return success_canvas.visible
