extends Node


signal power_changed


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Reactor")

@export var reactor_output: float = 100.0


# =========================================================
# ESTADO AUTORITATIVO / LOCAL
# =========================================================

var reactor_on: bool = false

var reactor_efficiency: float = 1.0

var consumers: Dictionary = {}


# =========================================================
# CACHE NETWORK — CLIENT
# =========================================================

var network_state_received: bool = false

var network_total_demand: float = 0.0

var network_available_output: float = 0.0

var network_power_balance: float = 0.0

var network_has_power: bool = false


# =========================================================
# AUTORIDAD
# =========================================================

func is_remote_client() -> bool:

	return (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	)


func can_modify_authoritative_state() -> bool:

	return not is_remote_client()


# =========================================================
# REACTOR
# =========================================================

func set_reactor_state(
	value: bool
):

	if not can_modify_authoritative_state():
		return


	if reactor_on == value:
		return


	reactor_on = value


	power_changed.emit()


func set_reactor_efficiency(
	value: float
):

	if not can_modify_authoritative_state():
		return


	var new_efficiency: float = clamp(
		value,
		0.0,
		1.0
	)


	if is_equal_approx(
		reactor_efficiency,
		new_efficiency
	):

		return


	reactor_efficiency = new_efficiency


	power_changed.emit()


# =========================================================
# CONSUMIDORES
# =========================================================

func set_consumer_demand(
	consumer_name: StringName,
	demand: float
):

	if not can_modify_authoritative_state():
		return


	var safe_demand: float = max(
		demand,
		0.0
	)


	if (
		consumers.has(
			consumer_name
		)
		and is_equal_approx(
			float(
				consumers[
					consumer_name
				]
			),
			safe_demand
		)
	):

		return


	consumers[
		consumer_name
	] = safe_demand


	power_changed.emit()


func remove_consumer(
	consumer_name: StringName
):

	if not can_modify_authoritative_state():
		return


	if not consumers.has(
		consumer_name
	):
		return


	consumers.erase(
		consumer_name
	)


	power_changed.emit()


func get_consumer_demand(
	consumer_name: StringName
) -> float:

	if not consumers.has(
		consumer_name
	):

		return 0.0


	return float(
		consumers[
			consumer_name
		]
	)


# =========================================================
# CÁLCULO INTERNO
# =========================================================

func calculate_total_demand() -> float:

	var total: float = 0.0


	for demand in consumers.values():

		total += float(
			demand
		)


	return total


func calculate_available_output() -> float:

	if not reactor_on:
		return 0.0


	return (
		reactor_output
		* reactor_efficiency
	)


func calculate_has_power() -> bool:

	if not reactor_on:
		return false


	if reactor_efficiency <= 0.0:
		return false


	return (
		calculate_total_demand()
		<= calculate_available_output()
	)


# =========================================================
# DEMANDA
# =========================================================

func get_total_demand() -> float:

	if (
		is_remote_client()
		and network_state_received
	):

		return network_total_demand


	return calculate_total_demand()


# =========================================================
# PRODUCCIÓN
# =========================================================

func get_reactor_efficiency() -> float:

	return reactor_efficiency


func get_max_reactor_output() -> float:

	return reactor_output


func get_available_output() -> float:

	if (
		is_remote_client()
		and network_state_received
	):

		return network_available_output


	return calculate_available_output()


func get_power_balance() -> float:

	if (
		is_remote_client()
		and network_state_received
	):

		return network_power_balance


	return (
		calculate_available_output()
		- calculate_total_demand()
	)


# =========================================================
# ESTADO
# =========================================================

func is_reactor_on() -> bool:

	return reactor_on


func has_power() -> bool:

	if (
		is_remote_client()
		and network_state_received
	):

		return network_has_power


	return calculate_has_power()


# =========================================================
# NETWORK — CONSTRUIR ESTADO
# =========================================================

func build_network_state() -> Dictionary:

	var consumer_state: Dictionary = {}


	for consumer_name in consumers.keys():

		consumer_state[
			str(
				consumer_name
			)
		] = float(
			consumers[
				consumer_name
			]
		)


	var total_demand: float = (
		calculate_total_demand()
	)


	var available_output: float = (
		calculate_available_output()
	)


	var power_balance: float = (
		available_output
		- total_demand
	)


	var current_has_power: bool = (
		calculate_has_power()
	)


	return {
		"reactor_on":
			reactor_on,

		"reactor_efficiency":
			reactor_efficiency,

		"reactor_output":
			reactor_output,

		"consumers":
			consumer_state,

		"total_demand":
			total_demand,

		"available_output":
			available_output,

		"power_balance":
			power_balance,

		"has_power":
			current_has_power
	}


# =========================================================
# NETWORK — APLICAR ESTADO
# =========================================================

func apply_network_state(
	state: Dictionary
):

	if not is_remote_client():
		return


	var changed: bool = false


	# -----------------------------------------------------
	# REACTOR ON/OFF
	# -----------------------------------------------------

	if state.has(
		"reactor_on"
	):

		var received_reactor_on: bool = bool(
			state[
				"reactor_on"
			]
		)


		if reactor_on != received_reactor_on:

			reactor_on = received_reactor_on

			changed = true


	# -----------------------------------------------------
	# EFICIENCIA
	# -----------------------------------------------------

	if state.has(
		"reactor_efficiency"
	):

		var received_efficiency: float = clamp(
			float(
				state[
					"reactor_efficiency"
				]
			),
			0.0,
			1.0
		)


		if not is_equal_approx(
			reactor_efficiency,
			received_efficiency
		):

			reactor_efficiency = (
				received_efficiency
			)

			changed = true


	# -----------------------------------------------------
	# OUTPUT CONFIGURADO
	# -----------------------------------------------------

	if state.has(
		"reactor_output"
	):

		var received_output: float = max(
			float(
				state[
					"reactor_output"
				]
			),
			0.0
		)


		if not is_equal_approx(
			reactor_output,
			received_output
		):

			reactor_output = (
				received_output
			)

			changed = true


	# -----------------------------------------------------
	# CONSUMIDORES
	# -----------------------------------------------------

	if state.has(
		"consumers"
	):

		var incoming_consumers = (
			state[
				"consumers"
			]
		)


		if incoming_consumers is Dictionary:

			var new_consumers: Dictionary = {}


			for consumer_key in (
				incoming_consumers.keys()
			):

				var consumer_name := StringName(
					str(
						consumer_key
					)
				)


				new_consumers[
					consumer_name
				] = max(
					float(
						incoming_consumers[
							consumer_key
						]
					),
					0.0
				)


			if consumers != new_consumers:

				consumers = new_consumers

				changed = true


	# -----------------------------------------------------
	# DERIVADOS AUTORITATIVOS
	# -----------------------------------------------------

	var received_total_demand: float = (
		float(
			state.get(
				"total_demand",
				calculate_total_demand()
			)
		)
	)


	var received_available_output: float = (
		float(
			state.get(
				"available_output",
				calculate_available_output()
			)
		)
	)


	var received_power_balance: float = (
		float(
			state.get(
				"power_balance",
				received_available_output
				- received_total_demand
			)
		)
	)


	var received_has_power: bool = bool(
		state.get(
			"has_power",
			false
		)
	)


	if not is_equal_approx(
		network_total_demand,
		received_total_demand
	):

		network_total_demand = (
			received_total_demand
		)

		changed = true


	if not is_equal_approx(
		network_available_output,
		received_available_output
	):

		network_available_output = (
			received_available_output
		)

		changed = true


	if not is_equal_approx(
		network_power_balance,
		received_power_balance
	):

		network_power_balance = (
			received_power_balance
		)

		changed = true


	if (
		network_has_power
		!= received_has_power
	):

		network_has_power = (
			received_has_power
		)

		changed = true


	if not network_state_received:

		network_state_received = true

		changed = true


	if changed:

		power_changed.emit()
