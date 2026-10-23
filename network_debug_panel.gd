extends CanvasLayer


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export var default_ip: String = "127.0.0.1"

@export var show_on_mobile: bool = false


# =========================================================
# UI
# =========================================================

var background: ColorRect

var title_label: Label

var state_label: Label

var peers_label: Label

var ip_field: LineEdit

var host_button: Button

var join_button: Button

var disconnect_button: Button


# =========================================================
# READY
# =========================================================

func _ready():

	# Por encima del HUD normal y del Mission UI.
	# Es temporal y sólo para desarrollo.
	layer = 150


	process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	create_ui()


	if (
		OS.has_feature("mobile")
		and not show_on_mobile
	):

		set_panel_visible(
			false
		)


# =========================================================
# PROCESS
# =========================================================

func _process(
	_delta: float
):

	update_panel()


# =========================================================
# CREAR UI
# =========================================================

func create_ui():

	# -----------------------------------------------------
	# FONDO
	# -----------------------------------------------------

	background = ColorRect.new()


	background.position = Vector2(
		525,
		15
	)


	background.size = Vector2(
		250,
		205
	)


	background.color = Color(
		0.02,
		0.02,
		0.02,
		0.92
	)


	background.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	add_child(
		background
	)


	# -----------------------------------------------------
	# TITLE
	# -----------------------------------------------------

	title_label = create_label(
		"NETWORK DEBUG",
		Vector2(
			540,
			25
		),
		Vector2(
			220,
			25
		)
	)


	# -----------------------------------------------------
	# STATE
	# -----------------------------------------------------

	state_label = create_label(
		"STATE: OFFLINE",
		Vector2(
			540,
			55
		),
		Vector2(
			220,
			25
		)
	)


	# -----------------------------------------------------
	# PEERS
	# -----------------------------------------------------

	peers_label = create_label(
		"PLAYERS: 0",
		Vector2(
			540,
			80
		),
		Vector2(
			220,
			25
		)
	)


	# -----------------------------------------------------
	# IP
	# -----------------------------------------------------

	ip_field = LineEdit.new()


	ip_field.position = Vector2(
		540,
		110
	)


	ip_field.size = Vector2(
		220,
		35
	)


	ip_field.text = (
		default_ip
	)


	ip_field.placeholder_text = (
		"Server IP"
	)


	ip_field.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	add_child(
		ip_field
	)


	# -----------------------------------------------------
	# HOST
	# -----------------------------------------------------

	host_button = create_button(
		"HOST",
		Vector2(
			540,
			155
		),
		Vector2(
			65,
			45
		)
	)


	host_button.pressed.connect(
		_on_host_pressed
	)


	# -----------------------------------------------------
	# JOIN
	# -----------------------------------------------------

	join_button = create_button(
		"JOIN",
		Vector2(
			610,
			155
		),
		Vector2(
			65,
			45
		)
	)


	join_button.pressed.connect(
		_on_join_pressed
	)


	# -----------------------------------------------------
	# DISCONNECT
	# -----------------------------------------------------

	disconnect_button = create_button(
		"DISCONNECT",
		Vector2(
			680,
			155
		),
		Vector2(
			80,
			45
		)
	)


	disconnect_button.pressed.connect(
		_on_disconnect_pressed
	)


# =========================================================
# LABEL
# =========================================================

func create_label(
	text_value: String,
	label_position: Vector2,
	label_size: Vector2
) -> Label:

	var label := Label.new()


	label.text = (
		text_value
	)


	label.position = (
		label_position
	)


	label.size = (
		label_size
	)


	label.add_theme_font_size_override(
		"font_size",
		14
	)


	label.add_theme_constant_override(
		"outline_size",
		4
	)


	label.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)


	label.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	add_child(
		label
	)


	return label


# =========================================================
# BUTTON
# =========================================================

func create_button(
	text_value: String,
	button_position: Vector2,
	button_size: Vector2
) -> Button:

	var button := Button.new()


	button.text = (
		text_value
	)


	button.position = (
		button_position
	)


	button.size = (
		button_size
	)


	button.focus_mode = (
		Control.FOCUS_NONE
	)


	button.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	add_child(
		button
	)


	return button


# =========================================================
# HOST
# =========================================================

func _on_host_pressed():

	NetworkManager.host_game()


# =========================================================
# JOIN
# =========================================================

func _on_join_pressed():

	NetworkManager.join_game(
		ip_field.text.strip_edges()
	)


# =========================================================
# DISCONNECT
# =========================================================

func _on_disconnect_pressed():

	NetworkManager.disconnect_from_game()


# =========================================================
# UPDATE
# =========================================================

func update_panel():

	if state_label == null:
		return


	var state_name: String = (
		NetworkManager.get_state_name()
	)


	state_label.text = (
		"STATE: "
		+ state_name
		+ " | ID: "
		+ str(
			NetworkManager.get_local_peer_id()
		)
	)


	peers_label.text = (
		"PLAYERS: "
		+ str(
			NetworkManager.get_player_count()
		)
		+ " | "
		+ str(
			NetworkManager.get_connected_peer_ids()
		)
	)


	host_button.disabled = (
		state_name != "OFFLINE"
	)


	join_button.disabled = (
		state_name != "OFFLINE"
	)


	disconnect_button.disabled = (
		state_name == "OFFLINE"
	)


# =========================================================
# VISIBILIDAD
# =========================================================

func set_panel_visible(
	value: bool
):

	background.visible = value

	title_label.visible = value

	state_label.visible = value

	peers_label.visible = value

	ip_field.visible = value

	host_button.visible = value

	join_button.visible = value

	disconnect_button.visible = value
