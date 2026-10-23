extends Node


@export_group("Debug Labels")
@export var show_labels: bool = true
@export var font_size: int = 14
@export var label_width: float = 180.0
@export var vertical_offset: float = -75.0


var object_definitions: Array = [

	{
		"path": "../Door",
		"name": "PUERTA"
	},

	{
		"path": "../Reactor",
		"name": "REACTOR"
	},

	{
		"path": "../OxygenGenerator",
		"name": "GENERADOR O2"
	},

	{
		"path": "../PumpRight",
		"name": "BOMBA DE AGUA"
	},

	{
		"path": "../HullBreach",
		"name": "BRECHA DEL CASCO"
	},

	{
		"path": "../PressureRegulator",
		"name": "REGULADOR PRESION"
	},

	{
		"path": "../DivingGearLocker",
		"name": "LOCKER TRAJE"
	},

	{
		"path": "../OxygenTankRack",
		"name": "RACK TANQUE O2"
	},

	{
		"path": "../MaterialLocker",
		"name": "LOCKER MATERIALES"
	},

	{
		"path": "../CraftingStation",
		"name": "ESTACION CRAFTING"
	},

	{
		"path": "../WeldingToolRack",
		"name": "PISTOLA SOLDAR"
	},

	{
		"path": "../WeldingFuelRack",
		"name": "COMBUSTIBLE SOLDAR"
	}
]


func _ready():

	if not show_labels:
		return


	create_object_labels()


func create_object_labels():

	for definition in object_definitions:

		var object_path: String = str(
			definition["path"]
		)


		var display_name: String = str(
			definition["name"]
		)


		var target = get_node_or_null(
			object_path
		)


		if target == null:
			continue


		create_label_for_object(
			target,
			display_name
		)


func create_label_for_object(
	target: Node,
	display_name: String
):

	if target.has_node(
		"DebugNameLabel"
	):
		return


	var label := Label.new()


	label.name = (
		"DebugNameLabel"
	)


	label.text = (
		display_name
	)


	label.position = Vector2(
		-label_width * 0.5,
		vertical_offset
	)


	label.size = Vector2(
		label_width,
		30.0
	)


	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)


	label.add_theme_font_size_override(
		"font_size",
		font_size
	)


	label.add_theme_constant_override(
		"outline_size",
		4
	)


	label.add_theme_color_override(
		"font_outline_color",
		Color(
			0.0,
			0.0,
			0.0,
			1.0
		)
	)


	label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	label.z_index = 100


	target.add_child(
		label
	)
