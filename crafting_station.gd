extends Node2D


@export_group("Crafting")
@export var active_recipe_id: String = "repair_kit"

@export var crafting_enabled: bool = true


var last_result: String = "NOT USED"

var crafted_count: int = 0


@onready var interaction_area: Area2D = (
	$InteractionArea
)


# =========================================================
# INICIALIZACIÓN
# =========================================================

func _ready():

	interaction_area.add_to_group(
		"interactable_area"
	)


	validate_active_recipe()

	queue_redraw()


# =========================================================
# VALIDAR RECETA
# =========================================================

func validate_active_recipe() -> bool:

	if active_recipe_id.is_empty():

		last_result = (
			"ERROR: NO RECIPE"
		)

		return false


	if not RecipeDB.has_recipe(
		active_recipe_id
	):

		last_result = (
			"ERROR: UNKNOWN RECIPE"
		)

		push_warning(
			"CraftingStation: receta desconocida: "
			+ active_recipe_id
		)

		return false


	if not RecipeDB.is_recipe_enabled(
		active_recipe_id
	):

		last_result = (
			"RECIPE DISABLED"
		)

		return false


	return true


# =========================================================
# INTERACCIÓN
# =========================================================

func interact(
	player
):

	if not crafting_enabled:

		last_result = (
			"CRAFTING DISABLED"
		)

		return


	if not validate_active_recipe():
		return


	var inventory = player.get_node_or_null(
		"Inventory"
	)


	if inventory == null:

		last_result = (
			"ERROR: NO INVENTORY"
		)

		return


	var requirements: Dictionary = (
		RecipeDB.get_requirements(
			active_recipe_id
		)
	)


	var output_item: String = (
		RecipeDB.get_output_item(
			active_recipe_id
		)
	)


	var output_quantity: int = (
		RecipeDB.get_output_quantity(
			active_recipe_id
		)
	)


	# -----------------------------------------------------
	# VALIDAR OUTPUT
	# -----------------------------------------------------

	if output_item.is_empty():

		last_result = (
			"ERROR: NO OUTPUT"
		)

		return


	if not ItemDB.has_definition(
		output_item
	):

		last_result = (
			"ERROR: UNKNOWN OUTPUT"
		)

		return


	# -----------------------------------------------------
	# VALIDAR MATERIALES
	# -----------------------------------------------------

	if not inventory.has_items(
		requirements
	):

		last_result = (
			"MISSING MATERIALS"
		)

		return


	# -----------------------------------------------------
	# VALIDAR ESPACIO ANTES DE CONSUMIR
	# -----------------------------------------------------

	if not inventory.can_add_item(
		output_item,
		output_quantity
	):

		last_result = (
			"INVENTORY FULL"
		)

		return


	# -----------------------------------------------------
	# CONSUMIR MATERIALES
	# -----------------------------------------------------

	var removed: bool = (
		inventory.remove_items(
			requirements
		)
	)


	if not removed:

		last_result = (
			"ERROR REMOVING MATERIALS"
		)

		return


	# -----------------------------------------------------
	# CREAR OUTPUT
	# -----------------------------------------------------

	var added: bool = (
		inventory.add_item(
			output_item,
			output_quantity
		)
	)


	if not added:

		# Seguridad:
		# si falla el output, devolvemos
		# todos los materiales.
		refund_requirements(
			inventory,
			requirements
		)


		last_result = (
			"ERROR ADDING OUTPUT"
		)

		return


	# -----------------------------------------------------
	# ÉXITO
	# -----------------------------------------------------

	crafted_count += 1


	last_result = (
		"CRAFTED "
		+ ItemDB.get_display_name(
			output_item
		)
		+ " x"
		+ str(
			output_quantity
		)
	)


	queue_redraw()


# =========================================================
# DEVOLVER MATERIALES
# =========================================================

func refund_requirements(
	inventory,
	requirements: Dictionary
):

	for item_id in requirements.keys():

		inventory.add_item(
			str(item_id),
			int(
				requirements[
					item_id
				]
			)
		)


# =========================================================
# CAMBIAR RECETA
# =========================================================

func set_active_recipe(
	recipe_id: String
) -> bool:

	if not RecipeDB.has_recipe(
		recipe_id
	):

		last_result = (
			"ERROR: UNKNOWN RECIPE"
		)

		return false


	active_recipe_id = recipe_id


	last_result = (
		"RECIPE SELECTED: "
		+ RecipeDB.get_display_name(
			recipe_id
		)
	)


	return true


func get_active_recipe_id() -> String:

	return active_recipe_id


func get_recipe_name() -> String:

	if not RecipeDB.has_recipe(
		active_recipe_id
	):

		return "INVALID RECIPE"


	return RecipeDB.get_display_name(
		active_recipe_id
	)


# =========================================================
# ESTADO
# =========================================================

func can_craft(
	inventory
) -> bool:

	if not crafting_enabled:
		return false


	if inventory == null:
		return false


	if not RecipeDB.has_recipe(
		active_recipe_id
	):
		return false


	if not RecipeDB.is_recipe_enabled(
		active_recipe_id
	):
		return false


	var requirements: Dictionary = (
		RecipeDB.get_requirements(
			active_recipe_id
		)
	)


	var output_item: String = (
		RecipeDB.get_output_item(
			active_recipe_id
		)
	)


	var output_quantity: int = (
		RecipeDB.get_output_quantity(
			active_recipe_id
		)
	)


	if not inventory.has_items(
		requirements
	):
		return false


	if not inventory.can_add_item(
		output_item,
		output_quantity
	):
		return false


	return true


func get_status_text(
	inventory
) -> String:

	if not crafting_enabled:

		return "DISABLED"


	if not RecipeDB.has_recipe(
		active_recipe_id
	):

		return "INVALID RECIPE"


	if not RecipeDB.is_recipe_enabled(
		active_recipe_id
	):

		return "RECIPE DISABLED"


	if inventory == null:

		return "NO INVENTORY"


	var requirements: Dictionary = (
		RecipeDB.get_requirements(
			active_recipe_id
		)
	)


	if not inventory.has_items(
		requirements
	):

		return "MISSING MATERIALS"


	var output_item: String = (
		RecipeDB.get_output_item(
			active_recipe_id
		)
	)


	var output_quantity: int = (
		RecipeDB.get_output_quantity(
			active_recipe_id
		)
	)


	if not inventory.can_add_item(
		output_item,
		output_quantity
	):

		return "INVENTORY FULL"


	return "READY"


# =========================================================
# TEXTO DE RECETA
# =========================================================

func get_recipe_text() -> String:

	if not RecipeDB.has_recipe(
		active_recipe_id
	):

		return "INVALID RECIPE"


	return RecipeDB.get_requirements_text(
		active_recipe_id
	)


# =========================================================
# DEBUG
# =========================================================

func get_last_result() -> String:

	return last_result


func get_crafted_count() -> int:

	return crafted_count


# =========================================================
# VISUAL
# =========================================================

func _draw():

	draw_rect(
		Rect2(
			-45,
			-40,
			90,
			80
		),
		Color(
			0.18,
			0.20,
			0.22,
			1.0
		)
	)


	draw_rect(
		Rect2(
			-35,
			-25,
			70,
			25
		),
		Color(
			0.45,
			0.47,
			0.50,
			1.0
		)
	)


	draw_circle(
		Vector2(
			0,
			18
		),
		10,
		Color(
			0.25,
			0.65,
			0.85,
			1.0
		)
	)
