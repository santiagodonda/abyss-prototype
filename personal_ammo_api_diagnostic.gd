extends Node


@export var start_on_run: bool = true


func _ready():

	if start_on_run:

		call_deferred(
			"run_diagnostic"
		)


func run_diagnostic():

	print("")
	print(
		"[QA DIAG] ========================================"
	)

	print(
		"[QA DIAG] PERSONAL AMMO API CHECK"
	)

	print(
		"[QA DIAG] ========================================"
	)


	var scene = (
		get_tree().current_scene
	)


	check_reference(
		"CurrentScene",
		scene
	)


	if scene == null:
		return


	var combat_manager = (
		scene.get_node_or_null(
			"NetworkCombatManager"
		)
	)


	var interaction_manager = (
		scene.get_node_or_null(
			"NetworkInteractionManager"
		)
	)


	var player = (
		scene.get_node_or_null(
			"Player"
		)
	)


	var ammo_rack = (
		scene.get_node_or_null(
			"HarpoonAmmoRack"
		)
	)


	check_reference(
		"NetworkCombatManager",
		combat_manager
	)


	check_reference(
		"NetworkInteractionManager",
		interaction_manager
	)


	check_reference(
		"Player",
		player
	)


	check_reference(
		"HarpoonAmmoRack",
		ammo_rack
	)


	var inventory = null
	var equipment = null
	var weapon_system = null


	if player != null:

		inventory = (
			player.get_node_or_null(
				"Inventory"
			)
		)


		equipment = (
			player.get_node_or_null(
				"Equipment"
			)
		)


		weapon_system = (
			player.get_node_or_null(
				"WeaponSystem"
			)
		)


	check_reference(
		"Player/Inventory",
		inventory
	)


	check_reference(
		"Player/Equipment",
		equipment
	)


	check_reference(
		"Player/WeaponSystem",
		weapon_system
	)


	print("")
	print(
		"[QA DIAG] --- NetworkCombatManager API ---"
	)


	check_method(
		combat_manager,
		"set_peer_harpoon_ammo"
	)


	check_method(
		combat_manager,
		"get_peer_harpoon_ammo"
	)


	check_method(
		combat_manager,
		"get_local_authoritative_harpoon_ammo"
	)


	check_method(
		combat_manager,
		"request_player_fire"
	)


	print("")
	print(
		"[QA DIAG] --- NetworkInteractionManager API ---"
	)


	check_method(
		interaction_manager,
		"get_player_position"
	)


	check_method(
		interaction_manager,
		"get_player_tool_id"
	)


	print("")
	print(
		"[QA DIAG] --- Inventory API ---"
	)


	check_method(
		inventory,
		"add_item"
	)


	check_method(
		inventory,
		"remove_item"
	)


	check_method(
		inventory,
		"has_item"
	)


	check_method(
		inventory,
		"get_item_quantity"
	)


	# Posibles nombres alternativos para detectar
	# inmediatamente cómo está implementado tu Inventory.

	check_method(
		inventory,
		"get_item_count"
	)


	check_method(
		inventory,
		"get_quantity"
	)


	print("")
	print(
		"[QA DIAG] --- Equipment API ---"
	)


	check_method(
		equipment,
		"equip_item"
	)


	check_method(
		equipment,
		"get_equipped_tool"
	)


	print("")
	print(
		"[QA DIAG] --- WeaponSystem API ---"
	)


	check_method(
		weapon_system,
		"fire_at"
	)


	check_method(
		weapon_system,
		"get_cooldown_remaining"
	)


	check_method(
		weapon_system,
		"is_network_fire_pending"
	)


	print("")
	print(
		"[QA DIAG] --- HarpoonAmmoRack API ---"
	)


	check_method(
		ammo_rack,
		"interact"
	)


	if ammo_rack != null:

		print(
			"[QA DIAG] Rack item_id = ",
			ammo_rack.get(
				"item_id"
			)
		)


		print(
			"[QA DIAG] Rack quantity = ",
			ammo_rack.get(
				"quantity_per_interaction"
			)
		)


	print("")
	print(
		"[QA DIAG] ========================================"
	)

	print(
		"[QA DIAG] CHECK COMPLETE"
	)

	print(
		"[QA DIAG] ========================================"
	)


func check_reference(
	label: String,
	reference
):

	if reference == null:

		print(
			"[QA DIAG][FAIL] Reference | ",
			label,
			" = NULL"
		)

	else:

		print(
			"[QA DIAG][PASS] Reference | ",
			label,
			" = ",
			reference.name
		)


func check_method(
	object,
	method_name: String
):

	if object == null:

		print(
			"[QA DIAG][SKIP] Method | ",
			method_name,
			" | Object is NULL"
		)

		return


	if object.has_method(
		method_name
	):

		print(
			"[QA DIAG][PASS] Method | ",
			object.name,
			".",
			method_name,
			"()"
		)

	else:

		print(
			"[QA DIAG][FAIL] Method | ",
			object.name,
			".",
			method_name,
			"() MISSING"
		)
