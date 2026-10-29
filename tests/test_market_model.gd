extends SceneTree
## Isolated synthetic source fixtures; these are not genuine gameplay evidence.

const Market = preload("res://game/market_model.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_catalog_and_all_shift_baselines()
	_test_legal_tasks_and_stock()
	_test_authoritative_motion()
	_test_no_automatic_checkout()
	_test_pause_resume_and_active_save()
	_test_once_only_payment()
	_test_practice_and_assisted_records()
	_test_invalid_snapshots()
	print("Market model source checks: %s checks, %s failures. Synthetic fixtures; native acceptance remains separate." % [checks, failures])
	quit(0 if failures == 0 else 1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Market model check failed: " + message)

func _play_baseline(model: RefCounted, limit: int = 4000) -> void:
	var ticks := 0
	while model.state.get("status", "") == "active" and ticks < limit:
		var action: Dictionary = model.baseline_action()
		if not action.is_empty():
			_expect(model.queue_task(str(action["kind"]), action["target"]), "baseline issues a legal action")
		model.step(0.1)
		if ticks % 50 == 0:
			_expect(model.conserved_stock(), "stock remains conserved during a real action sequence")
		ticks += 1
	_expect(ticks < limit, "baseline ends within its bounded simulation window")

func _test_catalog_and_all_shift_baselines() -> void:
	var model = Market.new()
	_expect(model.shifts.size() == 36, "36 authored shifts")
	var unique_titles: Dictionary = {}
	var chapters: Dictionary = {}
	for index: int in range(model.shifts.size()):
		var shift: Dictionary = model.shifts[index]
		_expect(int(shift["id"]) == index + 1, "stable contiguous shift IDs")
		_expect(not unique_titles.has(str(shift["title"])), "distinct authored shift titles")
		unique_titles[str(shift["title"])] = true
		chapters[str(shift["chapter_name"])] = int(chapters.get(str(shift["chapter_name"]), 0)) + 1
		model.new_shift(index + 1)
		_expect(model.state["capacities"].values().all(func(value: Variant) -> bool: return int(value) == 4), "baseline uses no upgrades")
		_play_baseline(model)
		_expect(model.state["status"] == "won", "unassisted campaign shift %s feasible" % [index + 1])
		_expect(int(model.state["served"]) == shift["orders"].size(), "baseline fulfils every authored basket %s" % [index + 1])
		_expect(int(model.state["lost"]) == 0, "baseline loses no customers %s" % [index + 1])
		_expect(not bool(model.state["assisted"]), "no ad assistance used")
		_expect(model.conserved_stock(), "stock conserved at completion")
	_expect(chapters.size() == 6 and chapters.values().all(func(value: Variant) -> bool: return int(value) == 6), "six chapters of six")
	model.new_shift(1)
	_expect(model.skus() == ["apple", "milk"] and model.definition["orders"].size() == 4, "tutorial has two products and four customers")
	_expect(bool(model.definition["tutorial"]), "first shift explicitly tutorial")
	model = null

func _test_legal_tasks_and_stock() -> void:
	var model = Market.new()
	model.new_shift(1)
	_expect(not model.queue_task("checkout", 0), "incomplete basket cannot be checked out")
	_expect(int(model.state["revenue"]) == 0, "invalid checkout cannot pay")
	_expect(not model.queue_task("restock", "unlisted"), "unavailable products cannot be stocked")
	_expect(model.queue_task("restock", "apple"), "legal restock starts")
	_expect(not model.queue_task("restock", "apple"), "duplicate active task rejected")
	_expect(model.queue_task("restock", "milk"), "one second task can be queued")
	_expect(not model.queue_task("restock", "milk"), "duplicate queued task rejected")
	_expect(model.cancel_queued(), "queued job cancels freely")
	_expect(model.state["queued_task"].is_empty(), "cancel removes queued job")
	for tick: int in range(150):
		model.step(0.1)
		if model.state["active_task"].is_empty():
			break
	_expect(int(model.state["restocks"]) == 1, "restock completes once")
	_expect(model.conserved_stock(), "restock moves real reserve rather than creates stock")
	_expect(int(model.state["shelves"]["apple"]) >= 1, "actual shelf receives reserve")
	for tick: int in range(200):
		if model.customer_by_id(0)["phase"] == "ready":
			break
		model.step(0.1)
	_expect(model.customer_by_id(0)["phase"] == "ready", "shopper physically reaches the shelf and counter with a complete basket")
	_expect(model.queue_task("checkout", 0), "complete basket can be checked out")
	for tick: int in range(150):
		model.step(0.1)
		if int(model.state["served"]) == 1:
			break
	_expect(int(model.state["served"]) == 1 and int(model.state["checkouts"]) == 1, "single fulfilled checkout recorded")
	_expect(int(model.state["revenue"]) == 4, "catalog apple price paid once")
	_expect(not model.queue_task("checkout", 0), "served basket cannot pay twice")
	_expect(model.conserved_stock(), "served goods remain in the stock conservation ledger")
	model = null

func _test_authoritative_motion() -> void:
	var model = Market.new()
	model.new_shift(1)
	var customer: Dictionary = model.customer_by_id(0)
	var entry := Vector2(float(customer["position"][0]), float(customer["position"][1]))
	_expect(entry.distance_to(Vector2(3.2, 3.6)) < 0.001, "customer enters at the genuine storefront position")
	var original_stock := int(model.state["shelves"]["apple"])
	for tick: int in range(10):
		var previous := Vector2(float(customer["position"][0]), float(customer["position"][1]))
		model.step(0.1)
		var current := Vector2(float(customer["position"][0]), float(customer["position"][1]))
		_expect(previous.distance_to(current) <= 0.2501, "customer model motion respects walking speed")
	_expect(int(model.state["shelves"]["apple"]) == original_stock and customer["basket"].is_empty(), "no stock pickup before physically reaching a shelf")
	var picked := false
	for tick: int in range(150):
		model.step(0.1)
		var events: Array = model.drain_events()
		if int(customer["basket"].get("apple", 0)) > 0:
			var point := Vector2(float(customer["position"][0]), float(customer["position"][1]))
			var pickup_events := 0
			for event: Dictionary in events:
				if event["kind"] == "pickup" and int(event["customer_id"]) == 0:
					var at_pickup := Vector2(float(event["position"][0]), float(event["position"][1]))
					_expect(at_pickup.distance_to(Vector2(-2.35, -0.3)) < 0.001, "actual stock changes at shelf interaction point")
					_expect(point.distance_to(at_pickup) <= 0.2501, "outer step cannot teleport the customer after a pickup substep")
					pickup_events += 1
			_expect(pickup_events == 1, "one actual pickup event records its exact moment and position")
			_expect(customer["phase"] == "to_checkout", "full basket must travel to checkout before input is ready")
			_expect(not model.queue_task("checkout", 0), "full basket in transit cannot be checked out remotely")
			picked = true
			break
	_expect(picked, "customer completes physical shelf pickup")
	for tick: int in range(150):
		model.step(0.1)
		if customer["phase"] == "ready":
			break
	var counter := Vector2(float(customer["position"][0]), float(customer["position"][1]))
	var target := Vector2(float(customer["target_position"][0]), float(customer["target_position"][1]))
	_expect(customer["phase"] == "ready" and counter.distance_to(target) < 0.001, "checkout-ready basket is actually at its stable queue position")
	_expect(model.queue_task("restock", "apple"), "clerk walking test queues a legal shelf")
	var restocked := false
	for tick: int in range(150):
		var previous := Vector2(float(model.state["clerk_position"][0]), float(model.state["clerk_position"][1]))
		model.step(0.1)
		var current := Vector2(float(model.state["clerk_position"][0]), float(model.state["clerk_position"][1]))
		_expect(previous.distance_to(current) <= 0.2501, "clerk model motion respects walking speed")
		if int(model.state["restocks"]) == 1:
			_expect(current.distance_to(Vector2(-2.35, -0.3)) < 0.001, "restock completes only at physical shelf")
			restocked = true
			break
	_expect(restocked, "clerk completes physical restocking")
	model = null

func _test_no_automatic_checkout() -> void:
	var model = Market.new()
	model.new_shift(1)
	for tick: int in range(1000):
		model.step(0.1)
	_expect(model.state["status"] == "lost", "unattended shop does not play itself")
	_expect(int(model.state["served"]) == 0 and int(model.state["revenue"]) == 0, "no automatic cashier or unfulfilled payout")
	model = null

func _test_pause_resume_and_active_save() -> void:
	var model = Market.new()
	model.new_shift(16)
	_expect(model.queue_task("restock", "apple"), "active task created for save fixture")
	model.step(0.1)
	model.set_paused(true)
	var paused := JSON.stringify(model.snapshot())
	model.step(12.0)
	_expect(JSON.stringify(model.snapshot()) == paused, "pause freezes clerk, customers, delivery and shift time")
	_expect(not model.queue_task("restock", "milk"), "paused input cannot queue tasks")
	var roundtrip: Variant = JSON.parse_string(paused)
	var restored = Market.new()
	_expect(restored.restore(roundtrip), "JSON cold-load preserves active task and queued customer state")
	_expect(_same_state_value(model.snapshot(), restored.snapshot()), "full active snapshot preserves every value across JSON numeric normalization")
	model.set_paused(false)
	restored.set_paused(false)
	var before := float(restored.state["elapsed"])
	restored.step(300.0)
	_expect(float(restored.state["elapsed"]) - before <= 0.2501, "first resumed OS delta cannot skip minutes")
	model.step(0.25)
	_expect(_same_state_value(model.snapshot(), restored.snapshot()), "bounded large frame equals ordinary legal time")
	_play_baseline(restored)
	_expect(restored.state["status"] == "won", "saved active shift remains feasible")
	model = null
	restored = null

func _same_state_value(a: Variant, b: Variant) -> bool:
	# Actual diagnostic showed JSON's16(int)->16.0(float), plus decimal
	# normalization of persisted Vector2 coordinates. Counts remain exact;
	# nonintegral values tolerate only1e-9 serialization rounding.
	if (a is int or a is float) and (b is int or b is float):
		if a is int or b is int or float(a) == floorf(float(a)) or float(b) == floorf(float(b)):
			return float(a) == float(b)
		return absf(float(a) - float(b)) <= 0.000000001
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key: Variant in a:
			if not b.has(key) or not _same_state_value(a[key], b[key]):
				return false
	elif a is Array:
		if a.size() != b.size():
			return false
		for index: int in range(a.size()):
			if not _same_state_value(a[index], b[index]):
				return false
	else:
		return a == b
	return true

func _test_once_only_payment() -> void:
	var model = Market.new()
	model.new_shift(1)
	var profile := {"coins": 0, "xp": 0, "served": 0, "restocks": 0, "best_combo": 0, "banked_runs": {}}
	_expect(model.bank_result(profile).is_empty(), "active shift cannot bank prematurely")
	_play_baseline(model)
	var first: Dictionary = model.bank_result(profile)
	var paid_coins := int(profile["coins"])
	var paid_xp := int(profile["xp"])
	_expect(bool(first["claimed"]) and paid_coins > 0 and paid_xp > 0, "first settled result banks genuine earnings")
	_expect(first.has_all(["run_id", "shift_id", "won", "coins", "xp", "served", "lost", "best_combo", "restocks", "assisted", "practice", "stars"]), "result exposes complete presentation contract")
	_expect(not bool(model.bank_result(profile)["claimed"]), "closing result twice cannot bank twice")
	_expect(int(profile["coins"]) == paid_coins and int(profile["xp"]) == paid_xp, "duplicate result leaves wallet and XP unchanged")
	var restored = Market.new()
	_expect(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "settled result cold-loads")
	_expect(not bool(restored.bank_result(profile)["claimed"]), "cold settled result cannot pay again")
	_expect(int(profile["coins"]) == paid_coins and int(profile["xp"]) == paid_xp, "cold relaunch retains exact wallet")
	_expect(int(profile["served"]) == 4, "served lifetime stat banks once")
	model = null
	restored = null

func _test_practice_and_assisted_records() -> void:
	var model = Market.new()
	model.new_shift(1, true, {"capacity": 2})
	_expect(int(model.state["capacities"]["apple"]) == 6, "profile capacity upgrade affects real shelves")
	_expect(not model.apply_earned_assistance("reserve"), "practice cannot consume rewarded aid")
	_play_baseline(model)
	var profile := {"coins": 7, "xp": 9, "served": 2, "restocks": 1, "best_combo": 1, "banked_runs": {}}
	var receipt: Dictionary = model.bank_result(profile)
	_expect(bool(receipt["practice"]) and int(receipt["coins"]) == 0 and int(receipt["xp"]) == 0, "practice is clearly separated from paid progression")
	_expect(int(profile["coins"]) == 7 and int(profile["xp"]) == 9 and int(profile["served"]) == 2, "practice cannot farm permanent rewards")
	model.new_shift(1)
	var produced := int(model.state["produced"])
	# This deliberately labelled source fixture represents an earned callback;
	# the native SDK itself is tested separately and is not simulated in UI.
	_expect(model.apply_earned_assistance("reserve"), "earned reserve context consumed once")
	_expect(not model.apply_earned_assistance("reserve"), "duplicate earned context refused")
	_expect(int(model.state["produced"]) == produced + 6 and model.conserved_stock(), "earned crate participates in stock ledger")
	_play_baseline(model)
	model.bank_result(profile)
	_expect(bool(model.state["assisted"]) and int(profile["best_combo"]) == 1, "assisted combo cannot raise unassisted leaderboard record")
	model = null

func _test_invalid_snapshots() -> void:
	var model = Market.new()
	model.new_shift(1)
	var invalid: Dictionary = model.snapshot()
	invalid["state"]["shelves"]["apple"] = -1
	var restored = Market.new()
	_expect(not restored.restore(invalid), "negative stock corruption rejected")
	invalid = model.snapshot()
	invalid["version"] = 999
	_expect(not restored.restore(invalid), "unknown schema rejected")
	for malformed_version: Variant in [{"bad": 1}, [2], "2", 2.5]:
		invalid = model.snapshot()
		invalid["version"] = malformed_version
		_expect(not restored.restore(invalid), "malformed schema version safely rejected before casting")
	invalid = model.snapshot()
	invalid["state"]["customers"].append(invalid["state"]["customers"][0].duplicate(true))
	_expect(not restored.restore(invalid), "duplicate customer corruption rejected")
	invalid = model.snapshot()
	invalid["state"]["customers"][0]["order"] = {"milk": 99}
	_expect(not restored.restore(invalid), "mismatched basket corruption rejected")
	for key: String in ["elapsed", "restocks", "arrival_cursor"]:
		for malformed: Variant in [{"bad": 1}, [1, 2]]:
			invalid = model.snapshot()
			invalid["state"][key] = malformed
			_expect(not restored.restore(invalid), "nonnumeric %s safely rejected before casting" % key)
	for key: String in ["served", "restocks", "arrival_cursor", "produced"]:
		invalid = model.snapshot()
		invalid["state"][key] = 1.25
		_expect(not restored.restore(invalid), "fractional integral counter %s rejected" % key)
	for malformed: Variant in [{"bad": 1}, [1, 2], "4"]:
		invalid = model.snapshot()
		invalid["state"]["shelves"]["apple"] = malformed
		_expect(not restored.restore(invalid), "nonnumeric shelf stock safely rejected")
	for key: String in ["practice", "paused", "assisted", "reward_used", "banked"]:
		invalid = model.snapshot()
		invalid["state"][key] = "false"
		_expect(not restored.restore(invalid), "string Boolean %s rejected" % key)
	invalid = model.snapshot()
	invalid["state"]["customers"][0]["position"] = [{"x": 1}, 0]
	_expect(not restored.restore(invalid), "malformed position rejected without numeric cast")
	_expect(restored.restore(model.snapshot()), "valid snapshot still accepted after failed restore attempts")
	model = null
	restored = null
