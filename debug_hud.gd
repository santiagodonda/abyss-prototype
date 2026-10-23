extends CanvasLayer


@onready var submarine_label: Label = $RoomStatus
@onready var health_bar: ProgressBar = $HealthBar

@onready var room_left = $"../RoomLeft"
@onready var room_right = $"../RoomRight"

@onready var submarine_environment = (
	$"../SubmarineEnvironment"
)

@onready var hull_breach = (
	$"../HullBreach"
)

@onready var pressure_regulator = (
	$"../PressureRegulator"
)

@onready var crafting_station = (
	$"../CraftingStation"
)

@onready var player = $"../Player"

@onready var player_vitals = (
	$"../Player/Vitals"
)

@onready var player_health = (
	$"../Player/Health"
)

@onready var player_equipment = (
	$"../Player/Equipment"
)

@onready var player_inventory = (
	$"../Player/Inventory"
)


var rooms_label: Label
var player_label: Label
var inventory_label: Label
var crafting_label: Label
var tools_label: Label


var submarine_background: ColorRect
var rooms_background: ColorRect
var player_background: ColorRect
var inventory_background: ColorRect
var crafting_background: ColorRect
var tools_background: ColorRect


var wrench_button: Button
var screwdriver_button: Button
var welding_tool_button: Button


# =========================================================
# INICIALIZACIÓN
# =========================================================

func _ready():

	create_backgrounds()

	create_labels()

	configure_health_bar()

	create_tool_hotbar()


# =========================================================
# FONDOS
# =========================================================

func create_backgrounds():

	submarine_background = create_background(
		Vector2(10, 10),
		Vector2(285, 185)
	)


	rooms_background = create_background(
		Vector2(305, 10),
		Vector2(360, 285)
	)


	player_background = create_background(
		Vector2(675, 10),
		Vector2(350, 440)
	)


	inventory_background = create_background(
		Vector2(10, 445),
		Vector2(300, 255)
	)


	crafting_background = create_background(
		Vector2(320, 445),
		Vector2(345, 210)
	)


	tools_background = create_background(
		Vector2(675, 455),
		Vector2(350, 145)
	)


func create_background(
	background_position: Vector2,
	background_size: Vector2
) -> ColorRect:

	var background := ColorRect.new()

	background.position = (
		background_position
	)

	background.size = (
		background_size
	)

	background.color = Color(
		0.05,
		0.05,
		0.05,
		0.72
	)

	background.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	add_child(
		background
	)

	move_child(
		background,
		0
	)

	return background


# =========================================================
# LABELS
# =========================================================

func create_labels():

	submarine_label.position = Vector2(
		25,
		20
	)

	submarine_label.size = Vector2(
		255,
		165
	)

	submarine_label.add_theme_font_size_override(
		"font_size",
		16
	)


	rooms_label = create_debug_label(
		Vector2(320, 20),
		Vector2(330, 260)
	)


	player_label = create_debug_label(
		Vector2(690, 20),
		Vector2(320, 375)
	)


	inventory_label = create_debug_label(
		Vector2(25, 455),
		Vector2(270, 230)
	)


	crafting_label = create_debug_label(
		Vector2(335, 455),
		Vector2(315, 185)
	)


	tools_label = create_debug_label(
		Vector2(690, 465),
		Vector2(320, 55)
	)


func create_debug_label(
	label_position: Vector2,
	label_size: Vector2
) -> Label:

	var new_label := Label.new()

	new_label.position = (
		label_position
	)

	new_label.size = (
		label_size
	)

	new_label.add_theme_font_size_override(
		"font_size",
		16
	)

	new_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	add_child(
		new_label
	)

	return new_label


# =========================================================
# HEALTH BAR
# =========================================================

func configure_health_bar():

	health_bar.position = Vector2(
		690,
		405
	)

	health_bar.size = Vector2(
		310,
		24
	)

	health_bar.min_value = 0.0

	health_bar.max_value = (
		player_health.max_health
	)

	health_bar.value = (
		player_health.current_health
	)

	health_bar.show_percentage = true


# =========================================================
# HOTBAR DE HERRAMIENTAS
# =========================================================

func create_tool_hotbar():

	wrench_button = create_tool_button(
		"WRENCH",
		Vector2(
			690,
			535
		)
	)


	screwdriver_button = create_tool_button(
		"SCREWDRIVER",
		Vector2(
			800,
			535
		)
	)


	welding_tool_button = create_tool_button(
		"WELDING",
		Vector2(
			910,
			535
		)
	)


	wrench_button.pressed.connect(
		_on_wrench_pressed
	)


	screwdriver_button.pressed.connect(
		_on_screwdriver_pressed
	)


	welding_tool_button.pressed.connect(
		_on_welding_tool_pressed
	)


func create_tool_button(
	button_text: String,
	button_position: Vector2
) -> Button:

	var button := Button.new()


	button.position = (
		button_position
	)


	button.size = Vector2(
		105,
		42
	)


	button.text = (
		button_text
	)


	button.add_theme_font_size_override(
		"font_size",
		13
	)


	button.focus_mode = (
		Control.FOCUS_NONE
	)


	button.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)


	add_child(
		button
	)


	return button


# =========================================================
# BOTONES
# =========================================================

func _on_wrench_pressed():

	select_tool_from_hud(
		"wrench"
	)


func _on_screwdriver_pressed():

	select_tool_from_hud(
		"screwdriver"
	)


func _on_welding_tool_pressed():

	select_tool_from_hud(
		"welding_tool"
	)


func select_tool_from_hud(
	item_id: String
):

	if player_equipment == null:
		return


	if not player_inventory.has_item(
		item_id,
		1
	):

		print(
			"[HUD] Tool not in inventory: ",
			item_id
		)

		return


	var success: bool = (
		player_equipment.select_tool(
			item_id
		)
	)


	if success:

		print(
			"[HUD] Active Tool: ",
			ItemDB.get_display_name(
				item_id
			)
		)


	else:

		print(
			"[HUD] Failed to select: ",
			item_id
		)


# =========================================================
# ACTUALIZACIÓN
# =========================================================

func _process(_delta):

	update_submarine_status()

	update_room_status()

	update_player_status()

	update_inventory_status()

	update_crafting_status()

	update_tools_status()

	update_health_bar()


# =========================================================
# SUBMARINO
# =========================================================

func update_submarine_status():

	var breach_status: String = "OPEN"


	if hull_breach.is_repaired():

		breach_status = "REPAIRED"


	submarine_label.text = (
		"SUBMARINE\n\n"

		+ "Depth: "
		+ str(
			round(
				submarine_environment.depth_meters
			)
		)
		+ " m\n"

		+ "External Pressure: "
		+ str(
			snapped(
				submarine_environment.external_pressure,
				0.01
			)
		)
		+ "\n"

		+ "Breach: "
		+ breach_status
		+ "\n"

		+ "Breach Inflow: "
		+ str(
			snapped(
				hull_breach.get_water_inflow_rate()
				* 100.0,
				0.1
			)
		)
		+ " %/s\n"

		+ "Pressure Regulator: "
		+ pressure_regulator.get_status_text()
	)


# =========================================================
# HABITACIONES
# =========================================================

func update_room_status():

	rooms_label.text = (
		"ROOM LEFT\n"

		+ "Water: "
		+ str(
			round(
				room_left.water_level
				* 100.0
			)
		)
		+ "%\n"

		+ "Oxygen: "
		+ str(
			round(
				room_left.oxygen_level
				* 100.0
			)
		)
		+ "%\n"

		+ "Pressure: "
		+ str(
			snapped(
				room_left.pressure,
				0.01
			)
		)
		+ "\n"

		+ "Temperature: "
		+ str(
			snapped(
				room_left.temperature,
				0.1
			)
		)
		+ " C\n\n"

		+ "ROOM RIGHT\n"

		+ "Water: "
		+ str(
			round(
				room_right.water_level
				* 100.0
			)
		)
		+ "%\n"

		+ "Oxygen: "
		+ str(
			round(
				room_right.oxygen_level
				* 100.0
			)
		)
		+ "%\n"

		+ "Pressure: "
		+ str(
			snapped(
				room_right.pressure,
				0.01
			)
		)
		+ "\n"

		+ "Temperature: "
		+ str(
			snapped(
				room_right.temperature,
				0.1
			)
		)
		+ " C"
	)


# =========================================================
# JUGADOR
# =========================================================

func update_player_status():

	var underwater_text: String = "NO"
	var suit_status: String = "NONE"
	var tank_status: String = "NONE"


	if player_vitals.is_underwater():

		underwater_text = "YES"


	if player_equipment.is_diving_suit_equipped():

		suit_status = "EQUIPPED"


	if player_equipment.is_oxygen_tank_equipped():

		tank_status = "EQUIPPED"


	var active_tool_name: String = "NONE"


	if player_equipment.has_method(
		"get_active_tool_display_name"
	):

		active_tool_name = (
			player_equipment.get_active_tool_display_name()
		)


	player_label.text = (
		"PLAYER\n\n"

		+ "Room: "
		+ player_vitals.get_room_id()
		+ "\n"

		+ "Target: "
		+ player.get_current_interactable_name()
		+ "\n"

		+ "Breath: "
		+ str(
			round(
				player_vitals.breath_level
				* 100.0
			)
		)
		+ "%\n"

		+ "Health: "
		+ str(
			round(
				player_health.current_health
			)
		)
		+ " / "
		+ str(
			round(
				player_health.max_health
			)
		)
		+ "\n"

		+ "Underwater: "
		+ underwater_text
		+ "\n"

		+ "Diving Suit: "
		+ suit_status
		+ "\n"

		+ "Oxygen Tank: "
		+ tank_status
		+ "\n"

		+ "Active Tool: "
		+ active_tool_name
		+ "\n"

		+ "Tank Oxygen: "
		+ str(
			round(
				player_equipment.get_tank_percentage()
				* 100.0
			)
		)
		+ "%\n"

		+ "Pressure Exposure: "
		+ player_vitals.get_pressure_status()
		+ "\n"

		+ "Safe Pressure: "
		+ str(
			snapped(
				player_vitals.get_effective_safe_pressure(),
				0.01
			)
		)
		+ "\n"

		+ "Status: "
		+ player_health.get_state_name()
		+ "\n"

		+ "Death Timer: "
		+ str(
			round(
				player_health.get_unconscious_time_remaining()
			)
		)
		+ " s"
	)


# =========================================================
# INVENTARIO
# =========================================================

func update_inventory_status():

	inventory_label.text = (
		"INVENTORY\n\n"

		+ "ItemDB: "
		+ player_inventory.get_item_database_status()
		+ "\n"

		+ "Last: "
		+ player_inventory.get_last_action()
		+ "\n"

		+ "Slots: "
		+ str(
			player_inventory.get_used_slots()
		)
		+ " / "
		+ str(
			player_inventory.max_slots
		)
		+ "\n\n"

		+ player_inventory.get_inventory_text()
	)


# =========================================================
# CRAFTING
# =========================================================

func update_crafting_status():

	var repair_kit_quantity: int = (
		player_inventory.get_item_quantity(
			"repair_kit"
		)
	)


	crafting_label.text = (
		"CRAFTING\n\n"

		+ "Recipe: Repair Kit\n"

		+ crafting_station.get_recipe_text()
		+ "\n\n"

		+ "Status: "
		+ crafting_station.get_status_text(
			player_inventory
		)
		+ "\n"

		+ "Last Action: "
		+ crafting_station.get_last_result()
		+ "\n"

		+ "Repair Kits: "
		+ str(
			repair_kit_quantity
		)
	)


# =========================================================
# HERRAMIENTAS
# =========================================================

func update_tools_status():

	var active_tool: String = "NONE"

	var available_tools: String = "NONE"


	if player_equipment.has_method(
		"get_active_tool_display_name"
	):

		active_tool = (
			player_equipment.get_active_tool_display_name()
		)


	if player_equipment.has_method(
		"get_available_tools_text"
	):

		available_tools = (
			player_equipment.get_available_tools_text()
		)


	tools_label.text = (
		"TOOLS\n"
		+ "Active: "
		+ active_tool
		+ "\n"
		+ "Available: "
		+ available_tools
	)


	# -----------------------------------------------------
	# HABILITAR / DESHABILITAR BOTONES
	# -----------------------------------------------------

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


	welding_tool_button.disabled = (
		not player_inventory.has_item(
			"welding_tool",
			1
		)
	)


	# -----------------------------------------------------
	# MARCAR HERRAMIENTA ACTIVA
	# -----------------------------------------------------

	var active_tool_id: String = (
		player_equipment.get_equipped_tool()
	)


	if active_tool_id == "wrench":

		wrench_button.text = (
			"> WRENCH <"
		)

	else:

		wrench_button.text = (
			"WRENCH"
		)


	if active_tool_id == "screwdriver":

		screwdriver_button.text = (
			"> SCREWDRIVER <"
		)

	else:

		screwdriver_button.text = (
			"SCREWDRIVER"
		)


	if active_tool_id == "welding_tool":

		welding_tool_button.text = (
			"> WELDING <"
		)

	else:

		welding_tool_button.text = (
			"WELDING"
		)


# =========================================================
# HEALTH
# =========================================================

func update_health_bar():

	health_bar.max_value = (
		player_health.max_health
	)

	health_bar.value = (
		player_health.current_health
	)
