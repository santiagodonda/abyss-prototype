extends CanvasLayer


# =========================================================
# REFERENCIAS
# =========================================================

@onready var player = $"../Player"

@onready var player_health = (
	$"../Player/Health"
)

@onready var player_vitals = (
	$"../Player/Vitals"
)

@onready var player_equipment = (
	$"../Player/Equipment"
)

@onready var player_inventory = (
	$"../Player/Inventory"
)

@onready var player_weapon_system = (
	get_node_or_null("../Player/WeaponSystem")
)

@onready var submarine_helm = (
	get_node_or_null("../SubmarineHelm")
)

@onready var submarine_status = (
	get_node_or_null("../SubmarineStatus")
)

@onready var submarine_turret = (
	get_node_or_null("../SubmarineTurret")
)

@onready var submarine_turret_console = (
	get_node_or_null("../SubmarineTurretConsole")
)


# =========================================================
# UI GENERAL
# =========================================================

var bottom_background: ColorRect

var health_label: Label
var health_bar: ProgressBar

var breath_label: Label
var breath_bar: ProgressBar

var tank_label: Label
var tank_bar: ProgressBar

var status_label: Label

var active_tool_label: Label

var wrench_button: Button
var screwdriver_button: Button
var welding_button: Button
var harpoon_button: Button

var ammo_label: Label
var fire_button: Button

var interact_button: Button

var move_up_button: Button
var move_down_button: Button
var move_left_button: Button
var move_right_button: Button


# =========================================================
# UI ESTADO DEL SUBMARINO
# =========================================================

var submarine_status_background: ColorRect
var submarine_status_label: Label


# =========================================================
# UI HELM
# =========================================================

var helm_background: ColorRect

var helm_title_label: Label
var helm_status_label: Label

var helm_ascend_100_button: Button
var helm_ascend_25_button: Button
var helm_hold_button: Button
var helm_descend_25_button: Button
var helm_descend_100_button: Button


# =========================================================
# UI TORRETA
# =========================================================

var turret_background: ColorRect

var turret_title_label: Label
var turret_status_label: Label
var turret_target_label: Label

var turret_fire_button: Button


# =========================================================
# INICIALIZACIÓN
# =========================================================

func _ready():

	layer = 20

	create_background()

	create_movement_ui()

	create_status_ui()

	create_tool_ui()

	create_weapon_ui()

	create_interaction_ui()

	create_submarine_status_ui()

	create_helm_ui()

	create_turret_ui()

	update_hud()


# =========================================================
# LIMPIEZA
# =========================================================

func _exit_tree():

	release_all_movement_actions()

	Input.action_release(
		"interact"
	)


# =========================================================
# FONDO INFERIOR
# =========================================================

func create_background():

	bottom_background = ColorRect.new()

	bottom_background.position = Vector2(
		15,
		505
	)

	bottom_background.size = Vector2(
		1250,
		195
	)

	bottom_background.color = Color(
		0.03,
		0.03,
		0.03,
		0.72
	)

	bottom_background.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	add_child(
		bottom_background
	)

	move_child(
		bottom_background,
		0
	)


# =========================================================
# MOVIMIENTO
# =========================================================

func create_movement_ui():

	move_up_button = create_button(
		"▲",
		Vector2(95, 525),
		Vector2(60, 55)
	)

	move_left_button = create_button(
		"◀",
		Vector2(30, 590),
		Vector2(60, 55)
	)

	move_down_button = create_button(
		"▼",
		Vector2(95, 590),
		Vector2(60, 55)
	)

	move_right_button = create_button(
		"▶",
		Vector2(160, 590),
		Vector2(60, 55)
	)

	move_up_button.button_down.connect(
		_on_move_up_down
	)

	move_up_button.button_up.connect(
		_on_move_up_up
	)

	move_down_button.button_down.connect(
		_on_move_down_down
	)

	move_down_button.button_up.connect(
		_on_move_down_up
	)

	move_left_button.button_down.connect(
		_on_move_left_down
	)

	move_left_button.button_up.connect(
		_on_move_left_up
	)

	move_right_button.button_down.connect(
		_on_move_right_down
	)

	move_right_button.button_up.connect(
		_on_move_right_up
	)


# =========================================================
# ESTADO PLAYER
# =========================================================

func create_status_ui():

	health_label = create_label(
		"HEALTH",
		Vector2(245, 520),
		Vector2(200, 25)
	)

	health_bar = create_bar(
		Vector2(245, 548),
		Vector2(190, 22)
	)

	breath_label = create_label(
		"BREATH",
		Vector2(245, 580),
		Vector2(200, 25)
	)

	breath_bar = create_bar(
		Vector2(245, 608),
		Vector2(190, 22)
	)

	tank_label = create_label(
		"TANK O2: NONE",
		Vector2(245, 642),
		Vector2(200, 24)
	)

	tank_bar = create_bar(
		Vector2(245, 670),
		Vector2(190, 18)
	)

	status_label = create_label(
		"",
		Vector2(470, 650),
		Vector2(400, 30)
	)


# =========================================================
# HERRAMIENTAS
# =========================================================

func create_tool_ui():

	active_tool_label = create_label(
		"ACTIVE TOOL: NONE",
		Vector2(470, 515),
		Vector2(300, 30)
	)

	wrench_button = create_button(
		"WRENCH",
		Vector2(470, 565),
		Vector2(120, 60)
	)

	screwdriver_button = create_button(
		"SCREWDRIVER",
		Vector2(600, 565),
		Vector2(145, 60)
	)

	welding_button = create_button(
		"WELDING",
		Vector2(755, 565),
		Vector2(125, 60)
	)

	harpoon_button = create_button(
		"HARPOON",
		Vector2(890, 565),
		Vector2(160, 60)
	)

	wrench_button.pressed.connect(
		_on_wrench_pressed
	)

	screwdriver_button.pressed.connect(
		_on_screwdriver_pressed
	)

	welding_button.pressed.connect(
		_on_welding_pressed
	)

	harpoon_button.pressed.connect(
		_on_harpoon_pressed
	)


# =========================================================
# PLAYER WEAPON
# =========================================================

func create_weapon_ui():

	ammo_label = create_label(
		"HARPOONS: 0",
		Vector2(775, 515),
		Vector2(145, 30)
	)

	fire_button = create_button(
		"FIRE",
		Vector2(930, 510),
		Vector2(120, 45)
	)

	fire_button.pressed.connect(
		_on_fire_pressed
	)

	fire_button.visible = false

	ammo_label.visible = false


# =========================================================
# INTERACT
# =========================================================

func create_interaction_ui():

	interact_button = create_button(
		"INTERACT",
		Vector2(1080, 545),
		Vector2(160, 125)
	)

	interact_button.button_down.connect(
		_on_interact_down
	)

	interact_button.button_up.connect(
		_on_interact_up
	)


# =========================================================
# SUBMARINE STATUS
# =========================================================

func create_submarine_status_ui():

	submarine_status_background = ColorRect.new()

	submarine_status_background.position = Vector2(
		20,
		20
	)

	submarine_status_background.size = Vector2(
		500,
		90
	)

	submarine_status_background.color = Color(
		0.03,
		0.03,
		0.03,
		0.82
	)

	submarine_status_background.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	add_child(
		submarine_status_background
	)

	submarine_status_label = create_label(
		"SUBMARINE: CHECKING",
		Vector2(35, 32),
		Vector2(470, 65)
	)

	submarine_status_label.add_theme_font_size_override(
		"font_size",
		17
	)

	submarine_status_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)


# =========================================================
# HELM
# =========================================================

func create_helm_ui():

	helm_background = ColorRect.new()

	helm_background.position = Vector2(
		770,
		30
	)

	helm_background.size = Vector2(
		480,
		175
	)

	helm_background.color = Color(
		0.03,
		0.03,
		0.03,
		0.88
	)

	helm_background.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	add_child(
		helm_background
	)

	helm_title_label = create_label(
		"HELM",
		Vector2(790, 45),
		Vector2(440, 30)
	)

	helm_title_label.add_theme_font_size_override(
		"font_size",
		20
	)

	helm_status_label = create_label(
		"",
		Vector2(790, 75),
		Vector2(440, 45)
	)

	helm_ascend_100_button = create_button(
		"-100",
		Vector2(790, 130),
		Vector2(80, 55)
	)

	helm_ascend_25_button = create_button(
		"-25",
		Vector2(880, 130),
		Vector2(75, 55)
	)

	helm_hold_button = create_button(
		"HOLD",
		Vector2(965, 130),
		Vector2(90, 55)
	)

	helm_descend_25_button = create_button(
		"+25",
		Vector2(1065, 130),
		Vector2(75, 55)
	)

	helm_descend_100_button = create_button(
		"+100",
		Vector2(1150, 130),
		Vector2(80, 55)
	)

	helm_ascend_100_button.pressed.connect(
		_on_helm_ascend_100
	)

	helm_ascend_25_button.pressed.connect(
		_on_helm_ascend_25
	)

	helm_hold_button.pressed.connect(
		_on_helm_hold
	)

	helm_descend_25_button.pressed.connect(
		_on_helm_descend_25
	)

	helm_descend_100_button.pressed.connect(
		_on_helm_descend_100
	)

	set_helm_ui_visible(
		false
	)


# =========================================================
# TORRETA UI
# =========================================================

func create_turret_ui():

	turret_background = ColorRect.new()

	turret_background.position = Vector2(
		750,
		215
	)

	turret_background.size = Vector2(
		500,
		210
	)

	turret_background.color = Color(
		0.03,
		0.03,
		0.03,
		0.90
	)

	turret_background.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	add_child(
		turret_background
	)


	turret_title_label = create_label(
		"SUBMARINE TURRET",
		Vector2(775, 230),
		Vector2(450, 30)
	)

	turret_title_label.add_theme_font_size_override(
		"font_size",
		20
	)


	turret_status_label = create_label(
		"",
		Vector2(775, 270),
		Vector2(450, 50)
	)


	turret_target_label = create_label(
		"",
		Vector2(775, 320),
		Vector2(450, 40)
	)


	turret_fire_button = create_button(
		"FIRE",
		Vector2(935, 365),
		Vector2(150, 50)
	)

	turret_fire_button.pressed.connect(
		_on_turret_fire_pressed
	)


	set_turret_ui_visible(
		false
	)


# =========================================================
# HELPERS UI
# =========================================================

func create_label(
	label_text: String,
	label_position: Vector2,
	label_size: Vector2
) -> Label:

	var label := Label.new()

	label.text = label_text

	label.position = label_position

	label.size = label_size

	label.add_theme_font_size_override(
		"font_size",
		16
	)

	label.add_theme_constant_override(
		"outline_size",
		4
	)

	label.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)

	label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	add_child(
		label
	)

	return label


func create_bar(
	bar_position: Vector2,
	bar_size: Vector2
) -> ProgressBar:

	var bar := ProgressBar.new()

	bar.position = bar_position

	bar.size = bar_size

	bar.min_value = 0.0

	bar.max_value = 100.0

	bar.value = 100.0

	bar.show_percentage = true

	add_child(
		bar
	)

	return bar


func create_button(
	button_text: String,
	button_position: Vector2,
	button_size: Vector2
) -> Button:

	var button := Button.new()

	button.text = button_text

	button.position = button_position

	button.size = button_size

	button.add_theme_font_size_override(
		"font_size",
		16
	)

	button.focus_mode = (
		Control.FOCUS_NONE
	)

	add_child(
		button
	)

	return button


# =========================================================
# PROCESS
# =========================================================

func _process(
	_delta
):

	update_hud()


# =========================================================
# UPDATE HUD
# =========================================================

func update_hud():

	update_health()

	update_breath()

	update_tank()

	update_tools()

	update_weapon_ui()

	update_status()

	update_submarine_status()

	update_helm()

	update_turret()


# =========================================================
# HEALTH
# =========================================================

func update_health():

	var health_percent: float = 0.0

	if player_health.max_health > 0.0:

		health_percent = (
			player_health.current_health
			/ player_health.max_health
			* 100.0
		)

	health_bar.value = health_percent

	health_label.text = (
		"HEALTH  "
		+ str(
			int(
				round(
					player_health.current_health
				)
			)
		)
		+ " / "
		+ str(
			int(
				round(
					player_health.max_health
				)
			)
		)
	)


# =========================================================
# BREATH
# =========================================================

func update_breath():

	var breath_percent: float = (
		player_vitals.breath_level
		* 100.0
	)

	breath_bar.value = breath_percent

	breath_label.text = (
		"BREATH  "
		+ str(
			int(
				round(
					breath_percent
				)
			)
		)
		+ "%"
	)


# =========================================================
# TANK
# =========================================================

func update_tank():

	var tank_equipped: bool = (
		player_equipment.is_oxygen_tank_equipped()
	)

	if not tank_equipped:

		tank_label.text = "TANK O2: NONE"

		tank_bar.value = 0.0

		tank_bar.visible = false

		return


	tank_bar.visible = true


	var tank_percent: float = (
		player_equipment.get_tank_percentage()
		* 100.0
	)

	tank_bar.value = tank_percent

	tank_label.text = (
		"TANK O2  "
		+ str(
			int(
				round(
					tank_percent
				)
			)
		)
		+ "%"
	)


# =========================================================
# TOOLS
# =========================================================

func update_tools():

	var active_tool_id: String = (
		player_equipment.get_equipped_tool()
	)


	var active_tool_name: String = "NONE"


	if not active_tool_id.is_empty():

		active_tool_name = (
			ItemDB.get_display_name(
				active_tool_id
			)
		)


	active_tool_label.text = (
		"ACTIVE TOOL: "
		+ active_tool_name
	)


	wrench_button.disabled = (
		not player_inventory.has_item(
			"wrench",
			1
		)
	)

	screwdriver_button.disabled = (
		not player_inventory.has_item(
			"screwdriver",
			1
		)
	)

	welding_button.disabled = (
		not player_inventory.has_item(
			"welding_tool",
			1
		)
	)

	harpoon_button.disabled = (
		not player_inventory.has_item(
			"harpoon_gun",
			1
		)
	)


	if active_tool_id == "wrench":

		wrench_button.text = "> WRENCH <"

	else:

		wrench_button.text = "WRENCH"


	if active_tool_id == "screwdriver":

		screwdriver_button.text = "> SCREWDRIVER <"

	else:

		screwdriver_button.text = "SCREWDRIVER"


	if active_tool_id == "welding_tool":

		welding_button.text = "> WELDING <"

	else:

		welding_button.text = "WELDING"


	if active_tool_id == "harpoon_gun":

		harpoon_button.text = "> HARPOON <"

	else:

		harpoon_button.text = "HARPOON"


# =========================================================
# PLAYER WEAPON
# =========================================================

func update_weapon_ui():

	var has_harpoon_gun: bool = (
		player_inventory.has_item(
			"harpoon_gun",
			1
		)
	)

	var ammo_quantity: int = (
		player_inventory.get_item_quantity(
			"harpoon_ammo"
		)
	)

	ammo_label.visible = (
		has_harpoon_gun
		or ammo_quantity > 0
	)

	ammo_label.text = (
		"HARPOONS: "
		+ str(
			ammo_quantity
		)
	)

	var active_tool_id: String = (
		player_equipment.get_equipped_tool()
	)

	var harpoon_active: bool = (
		active_tool_id
		== "harpoon_gun"
	)

	fire_button.visible = harpoon_active

	if not harpoon_active:
		return


	if player_weapon_system == null:

		fire_button.disabled = true

		fire_button.text = "NO SYSTEM"

		return


	if not player_vitals.is_exterior():

		fire_button.disabled = true

		fire_button.text = "OUTSIDE"

		return


	if ammo_quantity <= 0:

		fire_button.disabled = true

		fire_button.text = "NO AMMO"

		return


	if not player_weapon_system.can_fire():

		fire_button.disabled = true

		fire_button.text = "COOLDOWN"

		return


	var target = (
		find_nearest_weapon_target()
	)


	if target == null:

		fire_button.disabled = true

		fire_button.text = "NO TARGET"

		return


	fire_button.disabled = false

	fire_button.text = "FIRE"


# =========================================================
# PLAYER WEAPON TARGET
# =========================================================

func find_nearest_weapon_target():

	var active_tool_id: String = (
		player_equipment.get_equipped_tool()
	)

	if active_tool_id != "harpoon_gun":
		return null


	var maximum_range: float = (
		ItemDB.get_float_property(
			active_tool_id,
			"projectile_range",
			650.0
		)
	)


	return find_nearest_creature(
		player.global_position,
		maximum_range
	)


# =========================================================
# PLAYER FIRE
# =========================================================

func _on_fire_pressed():

	if player_weapon_system == null:
		return

	if not player_vitals.is_exterior():
		return

	if (
		player_equipment.get_equipped_tool()
		!= "harpoon_gun"
	):
		return


	var target = (
		find_nearest_weapon_target()
	)

	if target == null:
		return


	player_weapon_system.fire_at(
		target.global_position
	)


# =========================================================
# GENERIC CREATURE TARGET
# =========================================================

func find_nearest_creature(
	origin: Vector2,
	maximum_range: float
):

	var nearest_target: Node2D = null

	var nearest_distance: float = INF


	var candidates: Array = (
		get_tree().get_nodes_in_group(
			"damageable_creature"
		)
	)


	for candidate in candidates:

		if not is_instance_valid(
			candidate
		):
			continue


		if not (
			candidate is Node2D
		):
			continue


		if candidate.has_method(
			"is_dead"
		):

			if candidate.is_dead():
				continue


		var distance: float = (
			origin.distance_to(
				candidate.global_position
			)
		)


		if distance > maximum_range:
			continue


		if distance >= nearest_distance:
			continue


		nearest_distance = distance

		nearest_target = candidate


	return nearest_target


# =========================================================
# PLAYER STATUS
# =========================================================

func update_status():

	var text: String = (
		player_health.get_state_name()
	)

	if player_vitals.is_underwater():

		text += " | UNDERWATER"

	if player_equipment.is_diving_suit_equipped():

		text += " | SUIT"

	status_label.text = text


# =========================================================
# SUBMARINE STATUS
# =========================================================

func update_submarine_status():

	if submarine_status == null:

		submarine_status_label.text = (
			"SUBMARINE: STATUS UNAVAILABLE"
		)

		return


	var state_name: String = (
		submarine_status.get_state_name()
	)

	var reason_text: String = (
		submarine_status.get_reason_text()
	)


	submarine_status_label.text = (
		"SUBMARINE: "
		+ state_name
		+ "\n"
		+ reason_text
	)


	var state_color: Color = Color(
		0.85,
		0.85,
		0.85,
		1.0
	)


	match state_name:

		"NORMAL":

			state_color = Color(
				0.55,
				0.90,
				0.55,
				1.0
			)

		"CAUTION":

			state_color = Color(
				0.95,
				0.80,
				0.30,
				1.0
			)

		"DANGER":

			state_color = Color(
				1.0,
				0.55,
				0.20,
				1.0
			)

		"CRITICAL":

			state_color = Color(
				1.0,
				0.25,
				0.20,
				1.0
			)

		"LOST":

			state_color = Color(
				1.0,
				0.10,
				0.10,
				1.0
			)


	submarine_status_label.add_theme_color_override(
		"font_color",
		state_color
	)


# =========================================================
# HELM UPDATE
# =========================================================

func update_helm():

	if submarine_helm == null:

		set_helm_ui_visible(
			false
		)

		return


	var near_helm: bool = (
		player.get_current_interactable_name()
		== "SubmarineHelm"
	)


	set_helm_ui_visible(
		near_helm
	)


	if not near_helm:
		return


	var current_depth: float = (
		submarine_helm.get_current_depth()
	)

	var target_depth: float = (
		submarine_helm.get_target_depth()
	)

	var helm_status: String = (
		submarine_helm.get_status_text()
	)


	helm_status_label.text = (
		"DEPTH: "
		+ str(
			int(
				round(
					current_depth
				)
			)
		)
		+ " m"
		+ "    TARGET: "
		+ str(
			int(
				round(
					target_depth
				)
			)
		)
		+ " m"
		+ "\nSTATUS: "
		+ helm_status
	)


# =========================================================
# HELM VISIBILITY
# =========================================================

func set_helm_ui_visible(
	value: bool
):

	helm_background.visible = value

	helm_title_label.visible = value

	helm_status_label.visible = value

	helm_ascend_100_button.visible = value

	helm_ascend_25_button.visible = value

	helm_hold_button.visible = value

	helm_descend_25_button.visible = value

	helm_descend_100_button.visible = value


# =========================================================
# TURRET UPDATE
# =========================================================

func update_turret():

	if (
		submarine_turret == null
		or submarine_turret_console == null
	):

		set_turret_ui_visible(
			false
		)

		return


	var near_console: bool = (
		player.get_current_interactable_name()
		== "SubmarineTurretConsole"
	)


	set_turret_ui_visible(
		near_console
	)


	if not near_console:
		return


	var ammo: int = (
		submarine_turret.get_ammo()
	)


	var max_ammo: int = (
		submarine_turret.get_max_ammo()
	)


	var power_text: String = "OFFLINE"


	if submarine_turret.has_power():

		power_text = "ONLINE"


	turret_status_label.text = (
		"POWER: "
		+ power_text
		+ "    AMMO: "
		+ str(
			ammo
		)
		+ " / "
		+ str(
			max_ammo
		)
	)


	var target = (
		find_nearest_turret_target()
	)


	if target == null:

		turret_target_label.text = (
			"TARGET: NONE"
		)

	else:

		var target_distance: float = (
			submarine_turret.global_position.distance_to(
				target.global_position
			)
		)


		turret_target_label.text = (
			"TARGET: "
			+ target.name.to_upper()
			+ "    DIST: "
			+ str(
				int(
					round(
						target_distance
					)
				)
			)
		)


	update_turret_fire_button(
		target
	)


# =========================================================
# TURRET TARGET
# =========================================================

func find_nearest_turret_target():

	if submarine_turret == null:
		return null


	return find_nearest_creature(
		submarine_turret.global_position,
		submarine_turret.get_projectile_range()
	)


# =========================================================
# TURRET FIRE BUTTON
# =========================================================

func update_turret_fire_button(
	target
):

	if not submarine_turret.has_power():

		turret_fire_button.disabled = true

		turret_fire_button.text = (
			"NO POWER"
		)

		return


	if submarine_turret.get_ammo() <= 0:

		turret_fire_button.disabled = true

		turret_fire_button.text = (
			"NO AMMO"
		)

		return


	if (
		submarine_turret.get_cooldown_remaining()
		> 0.0
	):

		turret_fire_button.disabled = true

		turret_fire_button.text = (
			"COOLDOWN"
		)

		return


	if target == null:

		turret_fire_button.disabled = true

		turret_fire_button.text = (
			"NO TARGET"
		)

		return


	turret_fire_button.disabled = false

	turret_fire_button.text = "FIRE"


# =========================================================
# TURRET FIRE
# =========================================================

func _on_turret_fire_pressed():

	if submarine_turret == null:
		return


	var target = (
		find_nearest_turret_target()
	)


	if target == null:
		return


	submarine_turret.fire_at(
		target.global_position
	)


# =========================================================
# TURRET VISIBILITY
# =========================================================

func set_turret_ui_visible(
	value: bool
):

	turret_background.visible = value

	turret_title_label.visible = value

	turret_status_label.visible = value

	turret_target_label.visible = value

	turret_fire_button.visible = value


# =========================================================
# HELM BUTTONS
# =========================================================

func _on_helm_ascend_100():

	submarine_helm.ascend_100()


func _on_helm_ascend_25():

	submarine_helm.ascend_25()


func _on_helm_hold():

	submarine_helm.hold_current_depth()


func _on_helm_descend_25():

	submarine_helm.descend_25()


func _on_helm_descend_100():

	submarine_helm.descend_100()


# =========================================================
# TOOL BUTTONS
# =========================================================

func _on_wrench_pressed():

	player_equipment.select_tool(
		"wrench"
	)


func _on_screwdriver_pressed():

	player_equipment.select_tool(
		"screwdriver"
	)


func _on_welding_pressed():

	player_equipment.select_tool(
		"welding_tool"
	)


func _on_harpoon_pressed():

	player_equipment.select_tool(
		"harpoon_gun"
	)


# =========================================================
# INTERACT
# =========================================================

func _on_interact_down():

	Input.action_press(
		"interact"
	)


func _on_interact_up():

	Input.action_release(
		"interact"
	)


# =========================================================
# MOVEMENT
# =========================================================

func _on_move_up_down():

	Input.action_press(
		"move_up"
	)


func _on_move_up_up():

	Input.action_release(
		"move_up"
	)


func _on_move_down_down():

	Input.action_press(
		"move_down"
	)


func _on_move_down_up():

	Input.action_release(
		"move_down"
	)


func _on_move_left_down():

	Input.action_press(
		"move_left"
	)


func _on_move_left_up():

	Input.action_release(
		"move_left"
	)


func _on_move_right_down():

	Input.action_press(
		"move_right"
	)


func _on_move_right_up():

	Input.action_release(
		"move_right"
	)


func release_all_movement_actions():

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
