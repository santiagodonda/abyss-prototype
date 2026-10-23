extends CanvasLayer


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Display")

@export var show_on_desktop_for_debug: bool = false

@export var default_address: String = ""


@export_group("Layout")

@export var panel_position: Vector2 = Vector2(
	20.0,
	90.0
)

@export var panel_size: Vector2 = Vector2(
	540.0,
	260.0
)


# =========================================================
# UI
# =========================================================

var root: Control = null

var panel: PanelContainer = null

var toggle_button: Button = null

var address_input: LineEdit = null

var join_button: Button = null

var disconnect_button: Button = null

var status_label: Label = null


# =========================================================
# READY
# =========================================================

func _ready():

	process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	if not should_create_panel():
		return


	build_ui()

	connect_network_signals()

	refresh_status()


# =========================================================
# MOSTRAR PANEL
# =========================================================

func should_create_panel() -> bool:

	if OS.get_name() == "Android":
		return true


	return show_on_desktop_for_debug


# =========================================================
# CREAR UI
# =========================================================

func build_ui():

	# -----------------------------------------------------
	# ROOT
	# -----------------------------------------------------

	root = Control.new()

	root.name = (
		"AndroidNetworkRoot"
	)


	root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


	root.mouse_filter = (
		Control.MOUSE_FILTER_PASS
	)


	add_child(
		root
	)


	# -----------------------------------------------------
	# BOTÓN RED
	# -----------------------------------------------------

	toggle_button = Button.new()

	toggle_button.name = (
		"NetworkToggleButton"
	)


	toggle_button.text = (
		"RED"
	)


	toggle_button.position = Vector2(
		20.0,
		20.0
	)


	toggle_button.custom_minimum_size = Vector2(
		120.0,
		56.0
	)


	toggle_button.add_theme_font_size_override(
		"font_size",
		22
	)


	root.add_child(
		toggle_button
	)


	toggle_button.pressed.connect(
		_on_toggle_pressed
	)


	# -----------------------------------------------------
	# PANEL
	# -----------------------------------------------------

	panel = PanelContainer.new()

	panel.name = (
		"ConnectionPanel"
	)


	panel.position = (
		panel_position
	)


	panel.custom_minimum_size = (
		panel_size
	)


	root.add_child(
		panel
	)


	# -----------------------------------------------------
	# MARGEN
	# -----------------------------------------------------

	var margin := MarginContainer.new()


	margin.add_theme_constant_override(
		"margin_left",
		18
	)


	margin.add_theme_constant_override(
		"margin_right",
		18
	)


	margin.add_theme_constant_override(
		"margin_top",
		14
	)


	margin.add_theme_constant_override(
		"margin_bottom",
		14
	)


	panel.add_child(
		margin
	)


	# -----------------------------------------------------
	# CONTENIDO
	# -----------------------------------------------------

	var content := VBoxContainer.new()


	content.add_theme_constant_override(
		"separation",
		12
	)


	margin.add_child(
		content
	)


	# -----------------------------------------------------
	# TÍTULO
	# -----------------------------------------------------

	var title := Label.new()


	title.text = (
		"CONECTAR A HOST"
	)


	title.add_theme_font_size_override(
		"font_size",
		24
	)


	content.add_child(
		title
	)


	# -----------------------------------------------------
	# DIRECCIÓN
	# -----------------------------------------------------

	var address_label := Label.new()


	address_label.text = (
		"IP del PC Host:"
	)


	address_label.add_theme_font_size_override(
		"font_size",
		18
	)


	content.add_child(
		address_label
	)


	address_input = LineEdit.new()

	address_input.name = (
		"AddressInput"
	)


	address_input.placeholder_text = (
		"Ej: 192.168.1.35"
	)


	address_input.text = (
		default_address
	)


	address_input.custom_minimum_size = Vector2(
		490.0,
		58.0
	)


	address_input.add_theme_font_size_override(
		"font_size",
		22
	)


	address_input.virtual_keyboard_enabled = true


	content.add_child(
		address_input
	)


	# -----------------------------------------------------
	# BOTONES
	# -----------------------------------------------------

	var buttons := HBoxContainer.new()


	buttons.add_theme_constant_override(
		"separation",
		12
	)


	content.add_child(
		buttons
	)


	join_button = Button.new()

	join_button.name = (
		"JoinButton"
	)


	join_button.text = (
		"CONECTAR"
	)


	join_button.custom_minimum_size = Vector2(
		220.0,
		58.0
	)


	join_button.add_theme_font_size_override(
		"font_size",
		20
	)


	buttons.add_child(
		join_button
	)


	join_button.pressed.connect(
		_on_join_pressed
	)


	disconnect_button = Button.new()

	disconnect_button.name = (
		"DisconnectButton"
	)


	disconnect_button.text = (
		"DESCONECTAR"
	)


	disconnect_button.custom_minimum_size = Vector2(
		220.0,
		58.0
	)


	disconnect_button.add_theme_font_size_override(
		"font_size",
		20
	)


	buttons.add_child(
		disconnect_button
	)


	disconnect_button.pressed.connect(
		_on_disconnect_pressed
	)


	# -----------------------------------------------------
	# STATUS
	# -----------------------------------------------------

	status_label = Label.new()

	status_label.name = (
		"StatusLabel"
	)


	status_label.text = (
		"OFFLINE"
	)


	status_label.add_theme_font_size_override(
		"font_size",
		18
	)


	content.add_child(
		status_label
	)


# =========================================================
# NETWORK SIGNALS
# =========================================================

func connect_network_signals():

	NetworkManager.network_state_changed.connect(
		_on_network_state_changed
	)


	NetworkManager.connection_succeeded.connect(
		_on_connection_succeeded
	)


	NetworkManager.connection_failed.connect(
		_on_connection_failed
	)


	NetworkManager.disconnected_from_server.connect(
		_on_disconnected_from_server
	)


# =========================================================
# TOGGLE
# =========================================================

func _on_toggle_pressed():

	if panel == null:
		return


	panel.visible = (
		not panel.visible
	)


# =========================================================
# JOIN
# =========================================================

func _on_join_pressed():

	if address_input == null:
		return


	var address: String = (
		address_input.text.strip_edges()
	)


	if address.is_empty():

		set_status(
			"INGRESÁ LA IP DEL PC"
		)

		return


	address_input.release_focus()


	if OS.get_name() == "Android":

		DisplayServer.virtual_keyboard_hide()


	set_status(
		"CONECTANDO A "
		+ address
		+ ":"
		+ str(
			NetworkManager.DEFAULT_PORT
		)
		+ "..."
	)


	var started: bool = (
		NetworkManager.join_game(
			address
		)
	)


	if not started:

		set_status(
			"NO SE PUDO INICIAR LA CONEXIÓN"
		)


	refresh_buttons()


# =========================================================
# DISCONNECT
# =========================================================

func _on_disconnect_pressed():

	if not NetworkManager.is_online():

		refresh_status()

		return


	NetworkManager.disconnect_from_game()


	refresh_status()


# =========================================================
# NETWORK STATE
# =========================================================

func _on_network_state_changed(
	_new_state: String
):

	refresh_status()


# =========================================================
# SUCCESS
# =========================================================

func _on_connection_succeeded():

	set_status(
		"CONECTADO | PEER "
		+ str(
			NetworkManager.get_local_peer_id()
		)
	)


	if toggle_button != null:

		toggle_button.text = (
			"RED ✓"
		)


	# Cerramos el panel para que no moleste durante gameplay.
	if panel != null:

		panel.visible = false


	refresh_buttons()


# =========================================================
# FAIL
# =========================================================

func _on_connection_failed():

	set_status(
		"CONEXIÓN FALLIDA"
	)


	if toggle_button != null:

		toggle_button.text = (
			"RED"
		)


	if panel != null:

		panel.visible = true


	refresh_buttons()


# =========================================================
# SERVER DISCONNECTED
# =========================================================

func _on_disconnected_from_server():

	set_status(
		"HOST DESCONECTADO"
	)


	if toggle_button != null:

		toggle_button.text = (
			"RED"
		)


	if panel != null:

		panel.visible = true


	refresh_buttons()


# =========================================================
# STATUS
# =========================================================

func refresh_status():

	if status_label == null:
		return


	var state_name: String = (
		NetworkManager.get_state_name()
	)


	match state_name:

		"OFFLINE":

			set_status(
				"OFFLINE | Puerto 7777"
			)


		"CONNECTING":

			set_status(
				"CONECTANDO..."
			)


		"CLIENT":

			set_status(
				"CONECTADO | PEER "
				+ str(
					NetworkManager.get_local_peer_id()
				)
			)


		"HOST":

			set_status(
				"HOST | Puerto 7777"
			)


		_:

			set_status(
				state_name
			)


	refresh_buttons()


# =========================================================
# BUTTON STATE
# =========================================================

func refresh_buttons():

	if join_button == null:
		return


	if disconnect_button == null:
		return


	var state_name: String = (
		NetworkManager.get_state_name()
	)


	join_button.disabled = (
		state_name != "OFFLINE"
	)


	disconnect_button.disabled = (
		state_name != "CLIENT"
		and state_name != "HOST"
	)


# =========================================================
# SET STATUS
# =========================================================

func set_status(
	value: String
):

	if status_label == null:
		return


	status_label.text = (
		value
	)
