extends StaticBody2D


signal state_changed(
	is_open: bool
)


# =========================================================
# ESTADO
# =========================================================

var is_open: bool = false


# =========================================================
# REFERENCIAS
# =========================================================

@onready var door_collision: CollisionShape2D = (
	$CollisionShape2D
)


@onready var interaction_area: Area2D = (
	$InteractionArea
)


@onready var network_component = (
	$NetworkInteractable
)


# =========================================================
# READY
# =========================================================

func _ready():

	interaction_area.add_to_group(
		"interactable_area"
	)


	apply_door_state()

	queue_redraw()


# =========================================================
# INTERACCIÓN
# =========================================================

func interact(
	_player
):

	# =====================================================
	# OFFLINE
	# =====================================================

	if not NetworkManager.is_online():

		set_open(
			not is_open
		)

		return


	# =====================================================
	# MULTIPLAYER
	# =====================================================

	network_component.request_action(
		"interact"
	)


# =========================================================
# NETWORK — VALIDACIÓN ESPECÍFICA
# =========================================================

func network_validate_action(
	_peer_id: int,
	action: String,
	_payload: Dictionary
) -> bool:

	return (
		action
		== "interact"
	)


# =========================================================
# NETWORK — EJECUCIÓN
# =========================================================

func network_execute_action(
	_peer_id: int,
	action: String,
	_payload: Dictionary
):

	if action != "interact":
		return


	set_open(
		not is_open
	)


# =========================================================
# NETWORK — ESTADO
# =========================================================

func network_get_state() -> Dictionary:

	return {
		"is_open": is_open
	}


# =========================================================
# NETWORK — APLICAR ESTADO
# =========================================================

func network_apply_state(
	state: Dictionary
):

	if not state.has(
		"is_open"
	):

		return


	set_open(
		bool(
			state[
				"is_open"
			]
		)
	)


# =========================================================
# CAMBIAR ESTADO
# =========================================================

func set_open(
	value: bool
):

	if is_open == value:

		apply_door_state()

		queue_redraw()

		return


	is_open = value


	apply_door_state()


	state_changed.emit(
		is_open
	)


	queue_redraw()


# =========================================================
# ESTADO FÍSICO
# =========================================================

func apply_door_state():

	if door_collision == null:
		return


	door_collision.set_deferred(
		"disabled",
		is_open
	)


# =========================================================
# VISUAL
# =========================================================

func _draw():

	if is_open:

		draw_rect(
			Rect2(
				-15,
				-60,
				30,
				120
			),
			Color(
				0.2,
				0.8,
				0.3,
				0.5
			)
		)


	else:

		draw_rect(
			Rect2(
				-15,
				-60,
				30,
				120
			),
			Color(
				0.9,
				0.15,
				0.15,
				1.0
			)
		)
