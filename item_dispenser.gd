extends Node2D


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Item")

@export var item_id: String = ""

@export var quantity_per_interaction: int = 1

@export var auto_equip: bool = false


@export_group("Debug")

@export var show_debug_label: bool = true

@export var print_interaction_debug: bool = true


# =========================================================
# REFERENCIAS
# =========================================================

@onready var interaction_area: Area2D = (
	$InteractionArea
)


var network_combat_manager = null


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


	call_deferred(
		"resolve_network_combat_manager"
	)


	if show_debug_label:

		create_debug_label()


	queue_redraw()


	if print_interaction_debug:

		print(
			"[ITEM DISPENSER] Ready | Node=",
			name,
			" | Item=",
			item_id,
			" | Quantity=",
			quantity_per_interaction
		)


# =========================================================
# NETWORK COMBAT MANAGER
# =========================================================

func resolve_network_combat_manager():

	if (
		network_combat_manager != null
		and is_instance_valid(
			network_combat_manager
		)
	):

		return network_combat_manager


	network_combat_manager = null


	var scene = (
		get_tree().current_scene
	)


	if scene != null:

		var candidate = (
			scene.get_node_or_null(
				"NetworkCombatManager"
			)
		)


		if (
			candidate != null
			and is_instance_valid(
				candidate
			)
		):

			network_combat_manager = candidate


			if print_interaction_debug:

				print(
					"[ITEM DISPENSER] NetworkCombatManager resolved from scene | ",
					name
				)


			return network_combat_manager


	var managers: Array = (
		get_tree().get_nodes_in_group(
			"network_combat_manager"
		)
	)


	if not managers.is_empty():

		var candidate = (
			managers[0]
		)


		if (
			candidate != null
			and is_instance_valid(
				candidate
			)
		):

			network_combat_manager = candidate


			if print_interaction_debug:

				print(
					"[ITEM DISPENSER] NetworkCombatManager resolved by group | ",
					name
				)


			return network_combat_manager


	if print_interaction_debug:

		print(
			"[ITEM DISPENSER] NetworkCombatManager NOT FOUND | ",
			name
		)


	return null


# =========================================================
# INTERACCIÓN
# =========================================================

func interact(
	player
):

	if print_interaction_debug:

		print(
			"[ITEM DISPENSER][INTERACT] Node=",
			name,
			" | Item=",
			item_id,
			" | Online=",
			NetworkManager.is_online(),
			" | Host=",
			NetworkManager.is_host(),
			" | Client=",
			NetworkManager.is_client()
		)


	if player == null:

		if print_interaction_debug:

			print(
				"[ITEM DISPENSER][BLOCKED] Player is null"
			)

		return


	if item_id.is_empty():

		if print_interaction_debug:

			print(
				"[ITEM DISPENSER][BLOCKED] item_id is empty"
			)

		return


	if not ItemDB.has_definition(
		item_id
	):

		push_warning(
			"ItemDispenser: Item desconocido: "
			+ item_id
		)

		return


	# -----------------------------------------------------
	# HARPOON AMMO ONLINE
	# -----------------------------------------------------

	if (
		NetworkManager.is_online()
		and item_id == "harpoon_ammo"
	):

		if print_interaction_debug:

			print(
				"[NET AMMO][DISPENSER] Online harpoon pickup requested | Node=",
				name,
				" | Quantity=",
				quantity_per_interaction
			)


		var manager = (
			resolve_network_combat_manager()
		)


		if manager == null:

			print(
				"[NET AMMO][LOCAL REJECT] NetworkCombatManager missing"
			)

			return


		if not manager.has_method(
			"request_harpoon_ammo_pickup"
		):

			print(
				"[NET AMMO][LOCAL REJECT] Pickup API missing"
			)

			return


		var request_result: bool = bool(
			manager.request_harpoon_ammo_pickup()
		)


		if print_interaction_debug:

			print(
				"[NET AMMO][DISPENSER] Request sent | Result=",
				request_result
			)


		return


	# -----------------------------------------------------
	# OFFLINE / RESTO DE ITEMS
	# -----------------------------------------------------

	if print_interaction_debug:

		print(
			"[ITEM DISPENSER] Local inventory path | Item=",
			item_id
		)


	var inventory = (
		player.get_node_or_null(
			"Inventory"
		)
	)


	if inventory == null:

		if print_interaction_debug:

			print(
				"[ITEM DISPENSER][BLOCKED] Inventory not found"
			)

		return


	var added: bool = (
		inventory.add_item(
			item_id,
			quantity_per_interaction
		)
	)


	if print_interaction_debug:

		print(
			"[ITEM DISPENSER] Local add result | Item=",
			item_id,
			" | Quantity=",
			quantity_per_interaction,
			" | Added=",
			added
		)


	if not added:
		return


	# -----------------------------------------------------
	# AUTO EQUIP
	# -----------------------------------------------------

	if auto_equip:

		var equipment = (
			player.get_node_or_null(
				"Equipment"
			)
		)


		if equipment != null:

			equipment.equip_item(
				item_id
			)


# =========================================================
# PRIORIDAD
# =========================================================

func get_interaction_priority(
	_player
) -> int:

	return 20


# =========================================================
# LABEL
# =========================================================

func create_debug_label():

	debug_label = Label.new()


	debug_label.name = (
		"ItemDispenserLabel"
	)


	debug_label.position = Vector2(
		-80,
		-55
	)


	debug_label.size = Vector2(
		160,
		30
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


	update_debug_label()


# =========================================================
# ACTUALIZAR LABEL
# =========================================================

func update_debug_label():

	if debug_label == null:
		return


	if item_id.is_empty():

		debug_label.text = (
			"ITEM DISPENSER"
		)

		return


	debug_label.text = (
		ItemDB.get_display_name(
			item_id
		).to_upper()
	)


# =========================================================
# VISUAL
# =========================================================

func _draw():

	draw_rect(
		Rect2(
			-40,
			-30,
			80,
			60
		),
		Color(
			0.12,
			0.25,
			0.28,
			1.0
		)
	)


	draw_rect(
		Rect2(
			-25,
			-15,
			50,
			30
		),
		Color(
			0.20,
			0.45,
			0.50,
			1.0
		)
	)
