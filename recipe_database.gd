extends Node


const RECIPES: Dictionary = {

	# =====================================================
	# REPAIR KIT
	#
	# Receta temporal.
	# La mantenemos para validar el sistema genérico.
	# Su función definitiva se decidirá más adelante.
	# =====================================================

	"repair_kit": {

		"display_name": "Repair Kit",

		"enabled": true,

		"output_item": "repair_kit",

		"output_quantity": 1,

		"requirements": {
			"scrap_metal": 2,
			"electrical_component": 1,
			"rubber": 1
		}
	}
}


# =========================================================
# CONSULTAS
# =========================================================

func has_recipe(
	recipe_id: String
) -> bool:

	return RECIPES.has(
		recipe_id
	)


func get_recipe(
	recipe_id: String
) -> Dictionary:

	if not RECIPES.has(
		recipe_id
	):
		return {}


	return RECIPES[
		recipe_id
	].duplicate(
		true
	)


func is_recipe_enabled(
	recipe_id: String
) -> bool:

	var recipe: Dictionary = (
		get_recipe(
			recipe_id
		)
	)


	if recipe.is_empty():
		return false


	return bool(
		recipe.get(
			"enabled",
			false
		)
	)


# =========================================================
# INFORMACIÓN
# =========================================================

func get_display_name(
	recipe_id: String
) -> String:

	var recipe: Dictionary = (
		get_recipe(
			recipe_id
		)
	)


	if recipe.is_empty():
		return recipe_id


	return str(
		recipe.get(
			"display_name",
			recipe_id
		)
	)


func get_output_item(
	recipe_id: String
) -> String:

	var recipe: Dictionary = (
		get_recipe(
			recipe_id
		)
	)


	return str(
		recipe.get(
			"output_item",
			""
		)
	)


func get_output_quantity(
	recipe_id: String
) -> int:

	var recipe: Dictionary = (
		get_recipe(
			recipe_id
		)
	)


	return int(
		recipe.get(
			"output_quantity",
			1
		)
	)


func get_requirements(
	recipe_id: String
) -> Dictionary:

	var recipe: Dictionary = (
		get_recipe(
			recipe_id
		)
	)


	var requirements = recipe.get(
		"requirements",
		{}
	)


	if requirements is Dictionary:

		return requirements.duplicate(
			true
		)


	return {}


# =========================================================
# TEXTO PARA DEBUG / UI
# =========================================================

func get_requirements_text(
	recipe_id: String
) -> String:

	var requirements: Dictionary = (
		get_requirements(
			recipe_id
		)
	)


	if requirements.is_empty():
		return "No materials"


	var parts: Array[String] = []


	for item_id in requirements.keys():

		var quantity: int = int(
			requirements[
				item_id
			]
		)


		var item_name: String = (
			ItemDB.get_display_name(
				str(item_id)
			)
		)


		parts.append(
			str(quantity)
			+ " "
			+ item_name
		)


	return " + ".join(
		parts
	)
