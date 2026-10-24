extends RefCounted
## Deterministic service rules. The view never owns stock, payment or customer time.
## This model uses no nodes, timers, service SDKs or player-save files.

const DATA_PATH := "res://game/shifts.json"
const SNAPSHOT_VERSION := 2
const SKU_NAMES := {"apple": "Apples", "bread": "Bread", "milk": "Milk", "cereal": "Cereal", "greens": "Greens", "juice": "Juice"}
const PRICES := {"apple": 4, "bread": 5, "milk": 6, "cereal": 5, "greens": 4, "juice": 6}
const REGULARS := ["Mina", "Theo", "Jun", "Otis", "Ivy", "Sol"]
const WALK_SPEED := 2.5
const PICKUP_SECONDS := 0.75
const MAX_CUSTOMERS := 4
const SERVICE_KEYS := ["restock_apple","restock_bread","restock_milk","restock_cereal","restock_greens","restock_juice","checkout"]
const ENTRY := Vector2(3.2, 3.6)
const EXIT := Vector2(4.7, 4.3)
const CLERK_HOME := Vector2(0.0, 1.35)
const SKU_POSITIONS := {"apple": Vector2(-2.35, -1.35), "bread": Vector2(-0.15, -1.35), "milk": Vector2(2.05, -1.35), "cereal": Vector2(-2.35, 0.7), "greens": Vector2(-0.15, 0.7), "juice": Vector2(2.05, 0.7)}

var shifts: Array = []
var definition: Dictionary = {}
var state: Dictionary = {}
var last_error := ""
var _events: Array = []

func _init() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Market shift catalog is missing")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.get("shifts", null) is Array:
		shifts = parsed["shifts"]
	else:
		push_error("Market shift catalog is invalid")

func skus() -> Array:
	return definition.get("skus", []).duplicate()

func new_shift(shift_id: int, practice: bool = false, upgrades: Dictionary = {}) -> void:
	last_error = ""
	_events.clear()
	if shift_id < 1 or shift_id > shifts.size():
		last_error = "Choose an available shift."
		state = {}
		return
	definition = shifts[shift_id - 1].duplicate(true)
	var capacities: Dictionary = {}
	var shelves: Dictionary = {}
	var reserve: Dictionary = {}
	var capacity_bonus := clampi(int(upgrades.get("capacity", 0)), 0, 3)
	var reserve_bonus := clampi(int(upgrades.get("reserve", 0)), 0, 3)
	for sku: String in definition["skus"]:
		capacities[sku] = int(definition["capacity"]) + capacity_bonus
		shelves[sku] = mini(int(definition["starting_stock"].get(sku, 1)), int(capacities[sku]))
		reserve[sku] = int(definition["reserve"].get(sku, 0)) + reserve_bonus * 2
	var service_ranks: Dictionary = {}
	for key in SERVICE_KEYS: service_ranks[key] = clampi(int(upgrades.get(key,0)),0,3)
	state = {
		"service_ranks": service_ranks,
		"shift_id": shift_id, "run_id": "%s-%s-%s" % [shift_id, Time.get_unix_time_from_system(), Time.get_ticks_usec()],
		"status": "active", "practice": practice, "paused": false,
		"elapsed": 0.0, "remaining": float(definition["duration"]),
		"capacities": capacities, "shelves": shelves, "reserve": reserve,
		"customers": [], "arrival_cursor": 0, "delivery_cursor": 0,
		"active_task": {}, "queued_task": {}, "served": 0, "lost": 0,
		"clerk_position": [CLERK_HOME.x, CLERK_HOME.y], "clerk_motion": "idle",
		"revenue": 0, "xp": 0, "combo": 0, "best_combo": 0,
		"restocks": 0, "checkouts": 0, "assisted": false,
		"reward_used": false, "banked": false, "stars": 0,
		"produced": _total_stock(shelves, reserve), "picked": 0,
		"last_action": "Open the shop", "finish_reason": ""
	}
	_spawn_due_customers()

func set_paused(value: bool) -> void:
	if not state.is_empty():
		state["paused"] = value

func queue_task(kind: String, target: Variant) -> bool:
	last_error = ""
	if state.is_empty() or state["status"] != "active":
		return _reject("This shift has finished.")
	if bool(state["paused"]):
		return _reject("Resume the shop first.")
	if kind != "restock" and kind != "checkout":
		return _reject("Choose a shelf or a ready basket.")
	if kind == "restock":
		var sku := str(target)
		if not state["shelves"].has(sku):
			return _reject("That product is not on this shift.")
		if int(state["reserve"][sku]) <= 0:
			return _reject("No reserve left. Watch for the next delivery.")
		if int(state["shelves"][sku]) >= int(state["capacities"][sku]):
			return _reject("That shelf is already full.")
		target = sku
	else:
		# -1 is one explicit counter standby job, not an automatic cashier.
		if int(target) != -1:
			var customer := customer_by_id(int(target))
			if customer.is_empty() or customer["phase"] != "ready":
				return _reject("Wait until this basket is complete.")
		target = int(target)
	for slot: String in ["active_task", "queued_task"]:
		var existing: Dictionary = state[slot]
		if not existing.is_empty() and existing["kind"] == kind and existing["target"] == target:
			return _reject("That job is already in the clerk's queue.")
	if not state["queued_task"].is_empty():
		return _reject("Queue full. Tap the queued job to cancel it.")
	var key := "restock_"+str(target) if kind == "restock" else "checkout"
	var interaction := (1.0 if kind == "restock" else 1.1)/(1.0+.25*int(state.service_ranks.get(key,0)))
	var task := {"kind": kind, "target": target, "remaining": interaction, "duration": interaction, "interaction_remaining": interaction, "interaction_duration": interaction}
	if state["active_task"].is_empty():
		_start_task(task)
	else:
		state["queued_task"] = task
		_emit("task_queued", {"task": task.duplicate(true)})
	return true

func cancel_queued() -> bool:
	if state.is_empty() or state["queued_task"].is_empty():
		return false
	state["queued_task"] = {}
	_emit("queue_cancelled")
	return true

func step(delta: float) -> void:
	if state.is_empty() or state["status"] != "active" or bool(state["paused"]):
		return
	# Bounded substeps make long frames identical to ordinary play and prevent a
	# resumed OS frame from skipping arrivals, interactions or task completion.
	var left := clampf(delta, 0.0, 0.25)
	while left > 0.00001 and state["status"] == "active":
		var dt := minf(left, 0.05)
		left -= dt
		_tick(dt)

func _tick(dt: float) -> void:
	state["elapsed"] = float(state["elapsed"]) + dt
	if not bool(state["practice"]):
		state["remaining"] = maxf(0.0, float(definition["duration"]) - float(state["elapsed"]))
	_spawn_due_customers()
	_deliver_due_stock()
	_tick_customers(dt)
	_tick_task(dt)
	var all_arrived: bool = int(state["arrival_cursor"]) == definition["orders"].size()
	var all_done: bool = all_arrived
	for customer: Dictionary in state["customers"]:
		if customer["phase"] != "served" and customer["phase"] != "lost":
			all_done = false
			break
	if all_done:
		_finish("Every basket has left the shop.")
	elif not bool(state["practice"]) and float(state["remaining"]) <= 0.0:
		for customer: Dictionary in state["customers"]:
			if customer["phase"] != "served" and customer["phase"] != "lost":
				_lose_customer(customer)
		state["lost"] = definition["orders"].size() - int(state["served"])
		_finish("Closing time")

func _spawn_due_customers() -> void:
	while int(state["arrival_cursor"]) < definition["orders"].size():
		var inside := 0
		for visitor: Dictionary in state["customers"]:
			if visitor["phase"] != "served" and visitor["phase"] != "lost":
				inside += 1
		if inside >= MAX_CUSTOMERS:
			break
		var index := int(state["arrival_cursor"])
		var order: Dictionary = definition["orders"][index]
		if float(order["at"]) > float(state["elapsed"]) + 0.00001:
			break
		var customer := {
			"id": index, "name": str(order.get("name", REGULARS[index % REGULARS.size()])),
			"regular": maxi(0, REGULARS.find(str(order.get("name", REGULARS[index % REGULARS.size()])))), "order": order["basket"].duplicate(true),
			"basket": {}, "phase": "shopping", "patience": float(order["patience"]),
			"max_patience": float(order["patience"]), "pick_timer": PICKUP_SECONDS,
			"sku_target": "", "paid": false, "arrived_at": float(state["elapsed"]),
			"position": [ENTRY.x, ENTRY.y], "target_position": [ENTRY.x, ENTRY.y],
			"route": [], "motion_phase": "idle", "queue_slot": -1, "celebrate_remaining": 0.0,
			"stock_waiting":false, "waited_for_stock":false, "happy":false
		}
		state["customers"].append(customer)
		_target_customer_shelf(customer)
		state["arrival_cursor"] = index + 1
		_emit("arrival", {"customer_id": index})

func _tick_customers(dt: float) -> void:
	for customer: Dictionary in state["customers"]:
		if customer["phase"] == "served" or customer["phase"] == "lost":
			_tick_departure(customer, dt)
			continue
		# Practice has no ticking patience or closing time, but still requires all
		# actual stock and checkout decisions.
		if not bool(state["practice"]):
			customer["patience"] = maxf(0.0, float(customer["patience"]) - dt)
		if float(customer["patience"]) <= 0.0:
			_lose_customer(customer)
			continue
		if customer["phase"] == "ready":
			continue
		if customer["motion_phase"] == "walk":
			if not _advance_route(customer, dt):
				continue
			if customer["phase"] == "to_checkout":
				customer["phase"] = "ready"
				customer["motion_phase"] = "wait"
				_emit("basket_ready", {"customer_id": customer["id"]})
				continue
			customer["motion_phase"] = "interact"
			customer["pick_timer"] = PICKUP_SECONDS
			_update_stock_emote(customer)
			_emit("pickup_started", {"customer_id": customer["id"], "sku": customer["sku_target"]})
			continue
		_update_stock_emote(customer)
		customer["pick_timer"] = float(customer["pick_timer"]) - dt
		if float(customer["pick_timer"]) > 0.0:
			continue
		var needed := _next_needed(customer)
		customer["sku_target"] = needed
		if needed.is_empty():
			_target_customer_counter(customer)
		elif int(state["shelves"][needed]) > 0:
			customer["motion_phase"] = "interact"
			state["shelves"][needed] = int(state["shelves"][needed]) - 1
			customer["basket"][needed] = int(customer["basket"].get(needed, 0)) + 1
			customer["pick_timer"] = PICKUP_SECONDS
			state["picked"] = int(state["picked"]) + 1
			_emit("pickup", {"customer_id": customer["id"], "sku": needed, "position": customer["position"].duplicate(), "elapsed": state["elapsed"]})
			if _next_needed(customer).is_empty():
				_target_customer_counter(customer)
			elif _next_needed(customer) != needed:
				_target_customer_shelf(customer)
		else:
			customer["motion_phase"] = "wait"
			customer["pick_timer"] = 0.2

func _update_stock_emote(customer: Dictionary) -> void:
	var needed := _next_needed(customer)
	var waiting: bool = customer["phase"] == "shopping" and customer["motion_phase"] != "walk" and not needed.is_empty() and int(state["shelves"].get(needed,0)) <= 0
	customer["stock_waiting"] = waiting
	if waiting: customer["waited_for_stock"] = true

func _target_customer_shelf(customer: Dictionary) -> void:
	var sku := _next_needed(customer)
	if sku.is_empty():
		_target_customer_counter(customer)
		return
	customer["sku_target"] = sku
	var target: Vector2 = SKU_POSITIONS[sku] + Vector2(float(int(customer["id"]) % 2) * 0.2, 1.05)
	_set_route(customer, target)

func _target_customer_counter(customer: Dictionary) -> void:
	var taken: Dictionary = {}
	for visitor: Dictionary in state["customers"]:
		if visitor["phase"] == "to_checkout" or visitor["phase"] == "ready":
			taken[int(visitor["queue_slot"])] = true
	var slot := 0
	while taken.has(slot) and slot < MAX_CUSTOMERS - 1:
		slot += 1
	customer["queue_slot"] = slot
	customer["phase"] = "to_checkout"
	customer["stock_waiting"] = false
	customer["sku_target"] = ""
	var target := Vector2(-0.1 + float(slot % 2) * 0.55, 2.8 + floorf(float(slot) / 2.0) * 0.45)
	_set_route(customer, target)
	_emit("basket_complete", {"customer_id": customer["id"]})

func _tick_departure(customer: Dictionary, dt: float) -> void:
	if customer["motion_phase"] == "celebrate":
		customer["celebrate_remaining"] = maxf(0.0, float(customer["celebrate_remaining"]) - dt)
		if float(customer["celebrate_remaining"]) > 0.0:
			return
		_set_route(customer, EXIT + Vector2(float(int(customer["id"]) % 2) * 0.3, 0.0))
	if customer["motion_phase"] == "walk" and _advance_route(customer, dt):
		customer["motion_phase"] = "exited"

func _next_needed(customer: Dictionary) -> String:
	for sku: String in definition["skus"]:
		if int(customer["basket"].get(sku, 0)) < int(customer["order"].get(sku, 0)):
			return sku
	return ""

func _deliver_due_stock() -> void:
	var deliveries: Array = definition.get("deliveries", [])
	while int(state["delivery_cursor"]) < deliveries.size():
		var index := int(state["delivery_cursor"])
		var delivery: Dictionary = deliveries[index]
		if float(delivery["at"]) > float(state["elapsed"]) + 0.00001:
			break
		for sku: String in delivery["stock"]:
			var amount := int(delivery["stock"][sku])
			state["reserve"][sku] = int(state["reserve"][sku]) + amount
			state["produced"] = int(state["produced"]) + amount
		state["delivery_cursor"] = index + 1
		_emit("delivery", {"stock": delivery["stock"].duplicate(true)})

func _tick_task(dt: float) -> void:
	if state["active_task"].is_empty():
		state["clerk_motion"] = "idle"
		return
	var task: Dictionary = state["active_task"]
	if task["motion_phase"] == "travel":
		var arrived := _advance_route(task, dt)
		state["clerk_position"] = task["position"].duplicate()
		task["remaining"] = _route_distance(task) / WALK_SPEED + float(task["interaction_remaining"])
		if not arrived:
			state["clerk_motion"] = "walk"
			return
		task["motion_phase"] = "interact"
		state["clerk_motion"] = "interact"
		_emit("clerk_interact", {"task": task.duplicate(true)})
		return
	if task["kind"] == "checkout" and int(task["target"]) == -1:
		var ready: Dictionary = {}
		for customer: Dictionary in state["customers"]:
			if customer["phase"] == "ready" and (ready.is_empty() or int(customer["queue_slot"]) < int(ready["queue_slot"])): ready = customer
		if ready.is_empty():
			task["motion_phase"] = "wait"
			state["clerk_motion"] = "idle"
			state["last_action"] = "At checkout - waiting for a complete basket"
			# A new shelf job can release standby rather than deadlocking stock.
			if not state["queued_task"].is_empty(): _complete_task()
			return
		task["target"] = int(ready["id"])
		task["motion_phase"] = "interact"
		state["last_action"] = "Checking out "+str(ready["name"])
	state["clerk_motion"] = "interact"
	task["interaction_remaining"] = maxf(0.0, float(task["interaction_remaining"]) - dt)
	task["remaining"] = task["interaction_remaining"]
	if float(task["interaction_remaining"]) > 0.0:
		return
	if task["kind"] == "restock":
		var sku := str(task["target"])
		var amount := mini(int(state["capacities"][sku]) - int(state["shelves"][sku]), int(state["reserve"][sku]))
		if amount > 0:
			state["shelves"][sku] = int(state["shelves"][sku]) + amount
			state["reserve"][sku] = int(state["reserve"][sku]) - amount
			state["restocks"] = int(state["restocks"]) + 1
			state["last_action"] = "%s restocked +%s" % [SKU_NAMES[sku], amount]
			_emit("restocked", {"sku": sku, "amount": amount})
	else:
		var customer := customer_by_id(int(task["target"]))
		if not customer.is_empty() and customer["phase"] == "ready" and not bool(customer["paid"]) and _next_needed(customer).is_empty():
			var price := 0
			for sku: String in customer["order"]:
				price += int(PRICES[sku]) * int(customer["order"][sku])
			customer["paid"] = true
			customer["phase"] = "served"
			customer["stock_waiting"] = false
			customer["happy"] = not bool(customer.get("waited_for_stock",false)) and float(customer["patience"]) >= float(customer["max_patience"])*.5
			customer["motion_phase"] = "celebrate"
			customer["celebrate_remaining"] = 0.6
			customer["route"] = []
			state["served"] = int(state["served"]) + 1
			state["checkouts"] = int(state["checkouts"]) + 1
			state["combo"] = int(state["combo"]) + 1
			state["best_combo"] = maxi(int(state["best_combo"]), int(state["combo"]))
			state["revenue"] = int(state["revenue"]) + price
			state["xp"] = int(state["xp"]) + 5 + customer["order"].size()
			state["last_action"] = "%s served · +%s coins" % [customer["name"], price]
			_emit("checkout", {"customer_id": customer["id"], "coins": price})
	_complete_task()

func _complete_task() -> void:
	state["active_task"] = {}
	state["clerk_motion"] = "idle"
	if not state["queued_task"].is_empty():
		var queued: Dictionary = state["queued_task"]
		state["queued_task"] = {}
		_start_task(queued)

func _start_task(task: Dictionary) -> void:
	var target_position := CLERK_HOME
	if task["kind"] == "restock":
		target_position = SKU_POSITIONS[str(task["target"])] + Vector2(0.0, 1.05)
	task["position"] = state["clerk_position"].duplicate()
	_set_route(task, target_position)
	task["motion_phase"] = "travel"
	task["interaction_remaining"] = float(task["interaction_duration"])
	task["duration"] = _route_distance(task) / WALK_SPEED + float(task["interaction_duration"])
	task["remaining"] = task["duration"]
	state["active_task"] = task
	state["clerk_motion"] = "walk"
	state["last_action"] = "Restocking %s" % SKU_NAMES[str(task["target"])] if task["kind"] == "restock" else "Checking out %s" % customer_by_id(int(task["target"])).get("name", "counter - next complete basket")
	_emit("task_started", {"task": task.duplicate(true)})

func _lose_customer(customer: Dictionary) -> void:
	if customer["phase"] == "lost" or customer["phase"] == "served":
		return
	customer["phase"] = "lost"
	customer["stock_waiting"] = false
	customer["happy"] = false
	customer["motion_phase"] = "celebrate"
	customer["celebrate_remaining"] = 0.6
	customer["route"] = []
	state["lost"] = int(state["lost"]) + 1
	state["combo"] = 0
	_emit("customer_lost", {"customer_id": customer["id"]})

func _finish(reason: String) -> void:
	if state["status"] != "active":
		return
	var won := int(state["served"]) >= int(definition["target"])
	state["status"] = "won" if won else "lost"
	state["finish_reason"] = reason
	state["active_task"] = {}
	state["queued_task"] = {}
	state["clerk_motion"] = "idle"
	if won:
		state["xp"] = int(state["xp"]) + 10 + int(state["shift_id"])
		state["revenue"] = int(state["revenue"]) + int(definition["completion_bonus"])
		state["stars"] = 1
		if int(state["lost"]) == 0:
			state["stars"] = 2
			if float(state["elapsed"]) <= float(definition["mastery_seconds"]):
				state["stars"] = 3
	_emit("shift_finished", result())

func customer_by_id(customer_id: int) -> Dictionary:
	for customer: Dictionary in state.get("customers", []):
		if int(customer["id"]) == customer_id:
			return customer
	return {}

func result() -> Dictionary:
	if state.is_empty():
		return {}
	return {
		"run_id": state["run_id"], "shift_id": state["shift_id"], "won": state["status"] == "won",
		"coins": 0 if bool(state["practice"]) else int(state["revenue"]),
		"xp": 0 if bool(state["practice"]) else int(state["xp"]),
		"served": state["served"], "lost": state["lost"], "best_combo": state["best_combo"],
		"restocks": state["restocks"], "assisted": state["assisted"], "practice": state["practice"],
		"stars": state["stars"], "elapsed": state["elapsed"], "claimed": false
	}

func bank_result(profile: Dictionary) -> Dictionary:
	var receipt := result()
	if state.is_empty() or state["status"] == "active":
		return {}
	if not profile.get("banked_runs", null) is Dictionary:
		profile["banked_runs"] = {}
	var run_id := str(state["run_id"])
	if bool(state["banked"]) or profile["banked_runs"].has(run_id):
		state["banked"] = true
		return receipt
	if not bool(state["practice"]):
		profile["coins"] = int(profile.get("coins", 0)) + int(receipt["coins"])
		profile["xp"] = int(profile.get("xp", 0)) + int(receipt["xp"])
		profile["served"] = int(profile.get("served", 0)) + int(state["served"])
		profile["restocks"] = int(profile.get("restocks", 0)) + int(state["restocks"])
		if not bool(state["assisted"]):
			profile["best_combo"] = maxi(int(profile.get("best_combo", 0)), int(state["best_combo"]))
	profile["banked_runs"][run_id] = {"shift_id": state["shift_id"], "practice": state["practice"]}
	state["banked"] = true
	receipt["claimed"] = true
	return receipt

func apply_earned_assistance(kind: String) -> bool:
	# Caller is responsible for the genuine SDK earned context. Model still
	# consumes it at most once; closing or unavailable ads must never call this.
	if state.is_empty() or bool(state["reward_used"]) or bool(state["practice"]):
		return false
	if kind != "reserve" or state["status"] != "active":
		return false
	state["reward_used"] = true
	state["assisted"] = true
	for sku: String in definition["skus"]:
		state["reserve"][sku] = int(state["reserve"][sku]) + 3
		state["produced"] = int(state["produced"]) + 3
	_emit("earned_reserve")
	return true

func snapshot() -> Dictionary:
	return {"version": SNAPSHOT_VERSION, "state": state.duplicate(true)}

func restore(saved: Dictionary) -> bool:
	last_error = ""
	if not _whole(saved.get("version"), SNAPSHOT_VERSION, SNAPSHOT_VERSION) or not saved.get("state") is Dictionary:
		return _reject("This shift save cannot be read.")
	var candidate: Dictionary = saved["state"].duplicate(true)
	if not _whole(candidate.get("shift_id"), 1, shifts.size()) or not candidate.get("run_id") is String:
		return _reject("This shift save has no valid shift.")
	var shift_id := int(candidate["shift_id"])
	if candidate["run_id"].is_empty():
		return _reject("This shift save has no valid run.")
	if not candidate.has("service_ranks"): candidate["service_ranks"] = {}
	if not candidate["service_ranks"] is Dictionary: return _reject("This service upgrade save is invalid.")
	for key in SERVICE_KEYS:
		if not candidate["service_ranks"].has(key): candidate["service_ranks"][key] = 0
		if not _whole(candidate["service_ranks"][key],0,3): return _reject("This service upgrade save is invalid.")
	var required := ["shelves", "reserve", "capacities", "active_task", "queued_task"]
	for key: String in required:
		if not candidate.get(key) is Dictionary:
			return _reject("This shift save is incomplete.")
	if not candidate.get("customers") is Array or not candidate.get("status") is String or not candidate["status"] in ["active", "won", "lost"]:
		return _reject("This shift save is incomplete.")
	var shift: Dictionary = shifts[shift_id - 1]
	if not _valid_point(candidate.get("clerk_position")) or not candidate.get("clerk_motion") is String or not candidate["clerk_motion"] in ["idle", "walk", "interact"]:
		return _reject("This clerk position save is invalid.")
	for sku: String in shift["skus"]:
		if not _whole(candidate["capacities"].get(sku), 1, 12):
			return _reject("This shelf capacity save is invalid.")
		if not _whole(candidate["shelves"].get(sku), 0, int(candidate["capacities"][sku])) or not _whole(candidate["reserve"].get(sku), 0, 10000):
			return _reject("This shift's stock save is invalid.")
	for key: String in ["shelves", "reserve", "capacities"]:
		if candidate[key].size() != shift["skus"].size():
			return _reject("This shift has unexpected stock fields.")
	for key: String in ["elapsed", "remaining"]:
		if not _number(candidate.get(key), 0.0, 86400.0):
			return _reject("This shift save has invalid timing.")
	var scalar_keys := ["served", "lost", "revenue", "xp", "restocks", "checkouts", "arrival_cursor", "delivery_cursor", "combo", "best_combo", "produced", "picked", "stars"]
	for key: String in scalar_keys:
		if not _whole(candidate.get(key), 0, 1000000):
			return _reject("This shift save has invalid counters.")
	if int(candidate["arrival_cursor"]) > shift["orders"].size() or int(candidate["delivery_cursor"]) > shift.get("deliveries", []).size():
		return _reject("This shift save has invalid arrivals.")
	if candidate["customers"].size() != int(candidate["arrival_cursor"]):
		return _reject("This shift save has inconsistent arrivals.")
	for key: String in ["practice", "paused", "assisted", "reward_used", "banked"]:
		if not candidate.get(key) is bool:
			return _reject("This shift save has invalid lifecycle flags.")
	for key: String in ["last_action", "finish_reason"]:
		if not candidate.get(key) is String:
			return _reject("This shift save is incomplete.")
	var seen_customers: Dictionary = {}
	for customer: Variant in candidate["customers"]:
		if not customer is Dictionary or not customer.get("order") is Dictionary or not customer.get("basket") is Dictionary:
			return _reject("This basket save is incomplete.")
		if not _whole(customer.get("id"), 0, int(candidate["arrival_cursor"]) - 1) or not customer.get("phase") is String or not customer["phase"] in ["shopping", "to_checkout", "ready", "served", "lost"]:
			return _reject("This basket save is invalid.")
		for key in ["stock_waiting","waited_for_stock","happy"]:
			if not customer.has(key): customer[key] = false
			if not customer[key] is bool: return _reject("This customer emote save is invalid.")
		var customer_id := int(customer["id"])
		var expected: Dictionary = shift["orders"][customer_id]["basket"]
		if seen_customers.has(customer_id) or customer["order"].size() != expected.size():
			return _reject("This basket save has inconsistent orders.")
		seen_customers[customer_id] = true
		for sku: String in expected:
			if not _whole(customer["order"].get(sku), int(expected[sku]), int(expected[sku])):
				return _reject("This basket save has inconsistent orders.")
		for sku: Variant in customer["basket"]:
			if not sku is String or not expected.has(sku) or not _whole(customer["basket"][sku], 0, int(expected[sku])):
				return _reject("This basket's stock save is invalid.")
		for key: String in ["patience", "max_patience", "arrived_at", "celebrate_remaining"]:
			if not _number(customer.get(key), 0.0, 86400.0):
				return _reject("This basket save has invalid timing.")
		if not _number(customer.get("pick_timer"), -0.1, 86400.0) or not customer.get("paid") is bool or not customer.get("name") is String or not _whole(customer.get("regular"), 0, REGULARS.size() - 1):
			return _reject("This basket save has invalid identity or timing.")
		if not customer.get("sku_target") is String or not (customer["sku_target"].is_empty() or shift["skus"].has(customer["sku_target"])):
			return _reject("This basket save has an invalid shelf target.")
		if not _valid_point(customer.get("position")) or not _valid_point(customer.get("target_position")) or not _valid_route(customer.get("route")):
			return _reject("This basket save has an invalid path.")
		if not customer.get("motion_phase") is String or not customer["motion_phase"] in ["walk", "interact", "wait", "idle", "celebrate", "exited"] or not _whole(customer.get("queue_slot"), -1, MAX_CUSTOMERS - 1):
			return _reject("This basket save has an invalid motion state.")
	for slot: String in ["active_task", "queued_task"]:
		var task: Dictionary = candidate[slot]
		if not task.is_empty():
			if not task.get("kind") is String or not task["kind"] in ["restock", "checkout"]:
				return _reject("This clerk task save is invalid.")
			for key: String in ["remaining", "interaction_remaining"]:
				if not _number(task.get(key), 0.0, 86400.0):
					return _reject("This clerk task save has invalid timing.")
			for key: String in ["duration", "interaction_duration"]:
				if not _number(task.get(key), 0.001, 86400.0):
					return _reject("This clerk task save has invalid timing.")
			if task["kind"] == "restock" and (not task.get("target") is String or not shift["skus"].has(task["target"])):
				return _reject("This clerk task points to an unavailable shelf.")
			if task["kind"] == "checkout" and (not _whole(task.get("target"), -1, shift["orders"].size() - 1) or (int(task["target"]) != -1 and not seen_customers.has(int(task["target"])))):
				return _reject("This clerk task points to an unavailable basket.")
			if slot == "active_task":
				if not _valid_point(task.get("position")) or not _valid_point(task.get("target_position")) or not _valid_route(task.get("route")) or not task.get("motion_phase") is String or not task["motion_phase"] in ["travel", "interact", "wait"]:
					return _reject("This clerk task path save is invalid.")
	definition = shift.duplicate(true)
	state = candidate
	if not conserved_stock():
		state = {}
		return _reject("This shift save has inconsistent stock totals.")
	_events.clear()
	return true

func _number(value: Variant, minimum: float, maximum: float) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, float(minimum), float(maximum)) and float(value) == floorf(float(value))

func _valid_point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0], -12.0, 12.0) and _number(value[1], -12.0, 12.0)

func _valid_route(value: Variant) -> bool:
	if not value is Array or value.size() > 4:
		return false
	for point: Variant in value:
		if not _valid_point(point):
			return false
	return true

func conserved_stock() -> bool:
	if state.is_empty():
		return false
	var total := _total_stock(state["shelves"], state["reserve"])
	for customer: Dictionary in state["customers"]:
		for quantity: Variant in customer["basket"].values():
			total += int(quantity)
	return total == int(state["produced"])

func drain_events() -> Array:
	var result_events := _events.duplicate(true)
	_events.clear()
	return result_events

func baseline_action() -> Dictionary:
	# Explicit player strategy used by feasibility tests and optional coaching.
	# It issues ordinary legal actions and never changes shelves or rewards.
	if state.is_empty() or state["status"] != "active" or not state["active_task"].is_empty() or bool(state["paused"]):
		return {}
	var most_urgent: Dictionary = {}
	for customer: Dictionary in state["customers"]:
		if customer["phase"] == "ready" and (most_urgent.is_empty() or float(customer["patience"]) < float(most_urgent["patience"])):
			most_urgent = customer
	if not most_urgent.is_empty():
		return {"kind": "checkout", "target": most_urgent["id"]}
	for customer: Dictionary in state["customers"]:
		if customer["phase"] == "shopping":
			var needed := _next_needed(customer)
			if not needed.is_empty() and int(state["shelves"][needed]) < 1 and int(state["reserve"][needed]) > 0:
				return {"kind": "restock", "target": needed}
	for sku: String in definition["skus"]:
		if int(state["shelves"][sku]) <= 1 and int(state["reserve"][sku]) > 0:
			return {"kind": "restock", "target": sku}
	return {}

func _total_stock(shelves: Dictionary, reserve: Dictionary) -> int:
	var total := 0
	for quantity: Variant in shelves.values():
		total += int(quantity)
	for quantity: Variant in reserve.values():
		total += int(quantity)
	return total

func _set_route(actor: Dictionary, target: Vector2) -> void:
	var start := _position(actor["position"])
	var route: Array = []
	# Shelf rows have a full-width clear front aisle. The right-side aisle
	# connects rows and the street, avoiding shelf/counter geometry entirely.
	var start_zone := _aisle_zone(start.y)
	var target_zone := _aisle_zone(target.y)
	if start_zone != target_zone:
		_append_waypoint(route, Vector2(3.2, start.y), start)
		_append_waypoint(route, Vector2(3.2, target.y), start)
	_append_waypoint(route, target, start)
	actor["route"] = route
	actor["target_position"] = [target.x, target.y]
	actor["motion_phase"] = "walk"

func _append_waypoint(route: Array, point: Vector2, start: Vector2) -> void:
	var previous := start if route.is_empty() else _position(route.back())
	if previous.distance_to(point) > 0.001:
		route.append([point.x, point.y])

func _aisle_zone(z: float) -> int:
	return 0 if z < 0.5 else 1 if z < 2.4 else 2

func _advance_route(actor: Dictionary, dt: float) -> bool:
	var position := _position(actor["position"])
	var travel := WALK_SPEED * dt
	var route: Array = actor["route"]
	while not route.is_empty() and travel > 0.000001:
		var next := _position(route[0])
		var distance := position.distance_to(next)
		if distance <= travel + 0.000001:
			position = next
			travel -= distance
			route.pop_front()
		else:
			position = position.move_toward(next, travel)
			travel = 0.0
	actor["position"] = [position.x, position.y]
	return route.is_empty()

func _route_distance(actor: Dictionary) -> float:
	var position := _position(actor["position"])
	var distance := 0.0
	for point: Array in actor["route"]:
		var next := _position(point)
		distance += position.distance_to(next)
		position = next
	return distance

func _position(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

func _emit(kind: String, details: Dictionary = {}) -> void:
	var event := details.duplicate(true)
	event["kind"] = kind
	_events.append(event)

func _reject(reason: String) -> bool:
	last_error = reason
	return false
