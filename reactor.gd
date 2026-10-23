extends Node2D


# =========================================================
# ESTADO
# =========================================================

var is_on: bool = false

var last_efficiency: float = 1.0


# =========================================================
# REFERENCIAS
# =========================================================

@onready var interaction_area: Area2D = (
	$InteractionArea
)


@onready var power_system = (
	$"../PowerSystem"
)


@onready var repair_point = (
	$"../ReactorRepairPoint"
)


@onready var network_component = (
	$NetworkInteractable
)


# =========================================================
# INICIALIZACIÓN
# =========================================================

func _ready():

	interaction_area.add_to_group(
		"interactable_area"
	)


	power_system.set_reactor_state(
		false
	)


	# Host y Offline calculan la condición real.
	if (
		not NetworkManager.is_online()
		or NetworkManager.is_host()
	):

		update_reactor_efficiency(
			true
		)


	else:

		power_system.set_reactor_efficiency(
			last_efficiency
		)


	power_system.power_changed.connect(
		queue_redraw
	)


	queue_redraw()


# =========================================================
# ACTUALIZACIÓN
# =========================================================

func _process(
	_delta
):

	# Client multiplayer no simula
	# la condición del Reactor.
	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	update_reactor_efficiency(
		false
	)


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

		toggle_reactor()

		return


	# =====================================================
	# MULTIPLAYER
	# =====================================================

	network_component.request_action(
		"toggle"
	)


# =========================================================
# NETWORK — VALIDACIÓN
# =========================================================

func network_validate_action(
	_peer_id: int,
	action: String,
	_payload: Dictionary
) -> bool:

	return (
		action
		== "toggle"
	)


# =========================================================
# NETWORK — EJECUCIÓN
# =========================================================

func network_execute_action(
	_peer_id: int,
	action: String,
	_payload: Dictionary
):

	if action != "toggle":
		return


	toggle_reactor()


# =========================================================
# TOGGLE
# =========================================================

func toggle_reactor():

	if is_broken():

		set_reactor_on(
			false
		)

		return


	set_reactor_on(
		not is_on
	)


# =========================================================
# ON / OFF
# =========================================================

func set_reactor_on(
	value: bool
):

	if (
		value
		and is_broken()
	):

		value = false


	var changed: bool = (
		is_on != value
	)


	is_on = value


	power_system.set_reactor_state(
		is_on
	)


	if changed:

		queue_redraw()


# =========================================================
# CONDICIÓN
# =========================================================

func update_reactor_efficiency(
	force_update: bool
):

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	var efficiency: float = (
		get_repair_efficiency_multiplier()
	)


	if (
		not force_update
		and is_equal_approx(
			efficiency,
			last_efficiency
		)
	):

		return


	last_efficiency = efficiency


	power_system.set_reactor_efficiency(
		efficiency
	)


	if efficiency <= 0.0:

		if is_on:

			set_reactor_on(
				false
			)


	queue_redraw()


	if NetworkManager.is_host():

		network_component.broadcast_state()


# =========================================================
# EFICIENCIA DEL REPAIR POINT
# =========================================================

func get_repair_efficiency_multiplier() -> float:

	if repair_point == null:
		return 1.0


	if not repair_point.has_method(
		"get_efficiency_multiplier"
	):

		return 1.0


	return repair_point.get_efficiency_multiplier()


# =========================================================
# EFICIENCIA ACTUAL
# =========================================================

func get_efficiency_multiplier() -> float:

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return last_efficiency


	return get_repair_efficiency_multiplier()


# =========================================================
# ROTO
# =========================================================

func is_broken() -> bool:

	return (
		get_efficiency_multiplier()
		<= 0.0
	)


# =========================================================
# NETWORK — ESTADO
# =========================================================

func network_get_state() -> Dictionary:

	return {
		"is_on": is_on,
		"efficiency":
			get_efficiency_multiplier()
	}


# =========================================================
# NETWORK — APLICAR ESTADO
# =========================================================

func network_apply_state(
	state: Dictionary
):

	if state.has(
		"efficiency"
	):

		last_efficiency = clamp(
			float(
				state[
					"efficiency"
				]
			),
			0.0,
			1.0
		)


		power_system.set_reactor_efficiency(
			last_efficiency
		)


	if state.has(
		"is_on"
	):

		set_reactor_on(
			bool(
				state[
					"is_on"
				]
			)
		)


	queue_redraw()


# =========================================================
# INFORMACIÓN
# =========================================================

func get_effective_output() -> float:

	if not is_on:
		return 0.0


	return (
		power_system.get_max_reactor_output()
		* get_efficiency_multiplier()
	)


func get_status_text() -> String:

	if is_broken():
		return "BROKEN"


	if not is_on:
		return "OFF"


	return "ON"


# =========================================================
# VISUAL
# =========================================================

func _draw():

	draw_rect(
		Rect2(
			-50,
			-50,
			100,
			100
		),
		Color(
			0.20,
			0.22,
			0.24,
			1.0
		)
	)


	var indicator_color: Color


	if is_broken():

		indicator_color = Color(
			0.30,
			0.30,
			0.30,
			1.0
		)


	elif not is_on:

		indicator_color = Color(
			0.8,
			0.15,
			0.15,
			1.0
		)


	else:

		indicator_color = Color(
			0.2,
			0.8,
			0.3,
			1.0
		)


	draw_circle(
		Vector2.ZERO,
		20,
		indicator_color
	)
