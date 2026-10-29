extends SceneTree
## Isolated synthetic legal-action simulations; no real saves, SDK earns or native acceptance.
const Model = preload("res://game/market_model.gd")
const Profile = preload("res://game/profile.gd")
var checks := 0
var failures := 0

class FullscreenFixture extends Node:
	var active := false
	func fullscreen_ad_active() -> bool: return active
	func set_menu_visible(_value: bool) -> void: pass
	func menu_bottom_reserve(_reference: CanvasItem = null) -> float: return 0.0
	func unlock(_key: String) -> void: pass
	func submit(_key: String,_value: int) -> void: pass
	func round_finished() -> void: pass

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("Round Five Market: "+label)

func _initialize() -> void: _run.call_deferred()

func play(m: RefCounted, delivery: bool = true, limit: int = 5000) -> void:
	var ticks := 0
	while m.state.status == "active" and ticks < limit:
		var action: Dictionary = m.baseline_action(delivery)
		if not action.is_empty(): check(m.queue_task(action.kind,action.target),"legal ordinary action %d %s" % [m.state.shift_id,action.kind])
		m.step(.1)
		if ticks%50 == 0: check(m.conserved_stock(),"stock ledger conserved through legal play")
		ticks += 1
	check(ticks < limit,"simulation terminates within bounded active time")

func max_upgrades() -> Dictionary:
	var upgrades := {"capacity":3,"reserve":3}
	for key in Model.SERVICE_KEYS: upgrades[key] = 3
	return upgrades

func _run() -> void:
	if "--qa-isolated" not in OS.get_cmdline_user_args():
		push_error("Round Five requires isolated QA storage"); quit(1); return
	var m = Model.new()
	check(m.shifts.size() == 36 and m.legacy_shifts.size() == 36,"all 36 stable IDs retained in both catalogues")
	check(m.shifts[0].skus == ["apple","milk"],"only first shift has exactly apples and milk")
	for index in range(1,36): check(m.shifts[index].skus.size() >= 3,"level2 onwards has at least three products")
	check(m.shifts[7].skus.size() == 6,"all six goods by level8")
	check(m.shifts[1].orders[1].at < m.shifts[0].orders[1].at and m.shifts[35].orders[1].at < m.shifts[7].orders[1].at,"arrival cadence tightens after tutorial and later campaign")
	check(m.shifts[7].starting_stock.apple < m.shifts[1].starting_stock.apple,"later shelves begin with less stock")
	var required := 0
	for shift in m.shifts:
		check(float(shift.delivery_seconds) >= 20 and float(shift.delivery_seconds) <= 45,"each courier wait within20-45active seconds")
		for ranks in [{},max_upgrades()]:
			m.new_shift(int(shift.id),false,ranks)
			play(m)
			print("R5 BASELINE shift=%d ranks=%s status=%s served=%d lost=%d courier=%d elapsed=%.1f" % [shift.id,"base" if ranks.is_empty() else "max",m.state.status,m.state.served,m.state.lost,m.state.courier.collected,m.state.elapsed])
			check(m.state.status == "won" and m.state.served == shift.orders.size() and m.state.lost == 0,"all authored baskets feasible with ordinary delivery: shift%d"%shift.id)
			check(not m.state.assisted and m.conserved_stock(),"campaign baseline requires no ads and conserves all stock")
		if shift.delivery_required:
			required += 1
			var sku: String = shift.delivery_featured_sku
			var demand := 0
			for order in shift.orders: demand += int(order.basket.get(sku,0))
			var absolute_available := int(shift.starting_stock[sku])+int(shift.reserve[sku])+6+3
			check(demand > absolute_available and int(shift.target) == shift.orders.size(),"required shift cannot win without courier even maxreserve and one adcrate")
			m.new_shift(int(shift.id),false,max_upgrades())
			check(m.apply_earned_assistance("reserve"),"synthetic earned event supplies exactly ordinary +3 once")
			play(m,false)
			check(m.state.status == "lost" and m.state.courier.calls == 0,"no-delivery legal strategy cannot win designated shift%d"%shift.id)
	check(required >= 7,"seven or more genuinely supply-constrained delivery shifts")
	_test_courier()
	_test_legacy()
	_test_finished_v2_settlement()
	await _test_scene()
	print("MARKET ROUND FIVE: %d checks, %d failures. Synthetic source/runtime fixtures only."%[checks,failures])
	quit(0 if failures == 0 else 1)

func _test_courier() -> void:
	var m = Model.new(); m.new_shift(8)
	check(not m.call_delivery(),"cannot summon while all product reserves remain stocked")
	for tick in range(1000):
		var action: Dictionary = m.baseline_action()
		if not action.is_empty(): check(m.queue_task(action.kind,action.target),"reach depleted reserve using legal jobs")
		if m.state.courier.phase == "transit": break
		m.step(.1)
	check(m.state.courier.phase == "transit" and m.state.courier.calls == 1,"depleted reserve enables exactly one call")
	check(not m.call_delivery() and not m.queue_task("collect_delivery","front_door"),"duplicate call and early pickup rejected")
	var remaining: float = m.state.courier.remaining
	var stock: int = m.state.produced
	m.set_paused(true); var before := JSON.stringify(m.snapshot()); m.step(45)
	check(JSON.stringify(m.snapshot()) == before,"pause freezes courier and all shop state")
	var resumed = Model.new(); check(resumed.restore(JSON.parse_string(before)),"in-flight courier cold-loads")
	check(is_equal_approx(float(resumed.state.courier.remaining),remaining),"reload preserves exact remaining wait")
	resumed.set_paused(false)
	var wait_ticks := 0
	while resumed.state.courier.phase == "transit" and wait_ticks < 1000:
		resumed.step(.05); wait_ticks += 1
	check(resumed.state.courier.phase == "waiting" and absf(wait_ticks*.05-remaining) < .051,"arrival at specified active time")
	check(resumed.state.produced == stock,"courier arrival does not silently add stock")
	check(resumed.queue_task("collect_delivery","front_door"),"player can send clerk to meet actual courier")
	check(not resumed.queue_task("collect_delivery","front_door"),"duplicate parcel task cannot be queued")
	check(resumed.state.produced == stock,"parcel not awarded at button press")
	var picking = Model.new(); check(picking.restore(resumed.snapshot()),"clerk pickup route saves and reloads")
	for tick in range(300):
		picking.step(.05)
		if picking.state.courier.collected == 1: break
	check(picking.state.courier.collected == 1 and picking.state.courier.phase == "idle","one handoff completes at door")
	var point: Array = picking.state.clerk_position
	check(Vector2(point[0],point[1]).distance_to(Model.ENTRY) < .001,"clerk physically meets courier at front door")
	check(picking.state.produced == stock+8*picking.skus().size() and picking.conserved_stock(),"only collected parcel produces advertised real reserve stock")
	check(not picking.queue_task("collect_delivery","front_door"),"collected parcel cannot pay twice")
	for key in ["phase","remaining","calls","collected"]:
		var invalid: Dictionary = picking.snapshot(); invalid.state.courier[key] = {"bad":true}
		check(not Model.new().restore(invalid),"malformed courier field safely rejected: "+key)

func _test_legacy() -> void:
	for id in range(1,37):
		# Old catalogue and v2 schema fixture only, no player profile read or rewrite.
		var old = Model.new(); old.shifts = old.legacy_shifts.duplicate(true); old.new_shift(id)
		for tick in range(80):
			var action: Dictionary = old.baseline_action(false)
			if not action.is_empty(): old.queue_task(action.kind,action.target)
			old.step(.1)
		var snapshot: Dictionary = old.snapshot(); snapshot.version = 2; snapshot.erase("ruleset"); snapshot.state.erase("courier")
		var loaded = Model.new()
		check(loaded.restore(JSON.parse_string(JSON.stringify(snapshot))),"legacy v2 active shift restores%d"%id)
		check(loaded.ruleset == Model.LEGACY_RULESET and loaded.definition == old.definition,"v2 retains exact original authored orders and stock%d"%id)
		check(loaded.state.run_id == old.state.run_id and same_value(loaded.state.shelves,old.state.shelves) and same_value(loaded.state.reserve,old.state.reserve),"legacy identity/stock preserved%d"%id)
		var again = Model.new(); check(again.restore(loaded.snapshot()) and again.ruleset == Model.LEGACY_RULESET,"upgraded snapshot retains legacy ruleset%d"%id)
		play(again)
		check(again.state.status == "won" and again.state.lost == 0,"old active run remains legally completable%d"%id)
	var invalid: Dictionary = Model.new().snapshot()
	var fresh = Model.new(); fresh.new_shift(1); invalid = fresh.snapshot(); invalid.ruleset = "unknown"
	check(not Model.new().restore(invalid),"unknown ruleset rejected rather than using changed orders")

func same_value(a: Variant, b: Variant) -> bool:
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
			if not b.has(key) or not same_value(a[key], b[key]):
				return false
	elif a is Array:
		if a.size() != b.size():
			return false
		for index: int in range(a.size()):
			if not same_value(a[index], b[index]):
				return false
	else:
		return a == b
	return true

func _test_finished_v2_settlement() -> void:
	var old = Model.new(); old.shifts = old.legacy_shifts.duplicate(true); old.new_shift(1)
	play(old,false)
	check(old.state.status == "won","old catalogue result created by ordinary legal fixture play")
	var snapshot: Dictionary = old.snapshot(); snapshot.version = 2; snapshot.erase("ruleset"); snapshot.state.erase("courier")
	var restored = Model.new(); check(restored.restore(snapshot),"finished unbanked v2 result restores")
	var path := "user://qa_market_r5/legacy_result.json"
	var profile = Profile.new(path); profile.data = Profile.fresh()
	var paid: Dictionary = profile.settle_model(restored)
	check(paid.ok and paid.receipt.claimed,"finished v2 result settles normally once")
	check(int(paid.receipt.base_coins) == 28 and int(paid.receipt.xp) == 35,"original apples+bread v2 result retains28coins35XP")
	var balances := [profile.data.coins,profile.data.xp,profile.data.served,profile.data.completed_rounds]
	var disk = Profile.new(path); check(disk.load_profile(),"legacy settlement cold-loads durable profile")
	var duplicate = Model.new(); check(duplicate.restore(JSON.parse_string(JSON.stringify(snapshot))),"same original unbanked result reopens")
	var receipt: Dictionary = disk.settle_model(duplicate)
	check(receipt.ok and not receipt.receipt.claimed,"old original result cannot claim again after reload")
	check(same_value(balances,[disk.data.coins,disk.data.xp,disk.data.served,disk.data.completed_rounds]),"legacy coins/XP/service/progression unchanged by duplicate settle")
	var banked = Model.new(); check(banked.restore(restored.snapshot()),"banked legacy v3 wrapper retains ruleset")
	receipt = disk.settle_model(banked)
	check(receipt.ok and not receipt.receipt.claimed and same_value(balances,[disk.data.coins,disk.data.xp,disk.data.served,disk.data.completed_rounds]),"banked wrapper reopen remains once-only")

func resume_button(app: Node) -> void:
	var found := false
	for node in app.find_children("*","Button",true,false):
		if node is Button and node.text == "Resume the shop" and node.is_visible_in_tree():
			node.pressed.emit(); found = true; break
	check(found,"actual neutral Resume button exists")

func freeze_collection(app: Node, fake: FullscreenFixture, slot: String) -> void:
	app.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	app.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var frozen := JSON.stringify(app.model.snapshot())
	app._process(12); app._courier_action()
	check(JSON.stringify(app.model.snapshot()) == frozen and app.world.frozen,"background freezes exact "+slot+" courier task, stock and clock")
	await process_frame; await process_frame
	app.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	app.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	app._process(.1)
	check(JSON.stringify(app.model.snapshot()) == frozen and app.paused,"foreground return cannot advance "+slot+" courier task")
	resume_button(app); app._process(0)
	check(not app.paused and not app.model.state.paused,"explicit Resume releases background "+slot+" task")
	fake.active = true; app._process(.1)
	frozen = JSON.stringify(app.model.snapshot())
	app._process(12); app._courier_action()
	check(JSON.stringify(app.model.snapshot()) == frozen and app.world.frozen,"fullscreen cover freezes exact "+slot+" courier task and supply")
	fake.active = false; app._process(.1)
	check(JSON.stringify(app.model.snapshot()) == frozen and app.paused,"fullscreen dismissal cannot silently advance "+slot+" task")
	resume_button(app); app._process(0)
	check(not app.paused and not app.model.state.paused,"neutral Resume releases fullscreen "+slot+" task")

func _test_scene() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(960,1440)
	var app = load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	await process_frame; await process_frame
	app.set_process(false); app.services = null
	app.profile.data = Profile.fresh(); app.profile.data.tutorial_seen = true; app.background = false
	app._start_shift(8); app.paused = false; app.model.set_paused(false)
	check(app.courier_button.text == "Call for delivery" and app.courier_button.disabled,"actual scene shows ordinary courier with eligibility")
	for tick in range(1000):
		var action: Dictionary = app.model.baseline_action()
		if not action.is_empty(): app.model.queue_task(action.kind,action.target)
		app.model.step(.1)
		if app.model.state.courier.phase == "waiting": break
	app._refresh_game(); app.world.sync(app.model.state,0)
	check(app.courier_button.text == "Meet courier at door" and not app.courier_button.disabled,"waiting courier offers explicit meet action")
	check(app.world.courier.visible and app.world.courier_parcel.visible and app.world.courier_label.visible,"licensed character and parcel visible at door")
	check(app.world.courier.position.distance_to(Vector3(3.2,.04,3.6)) < .001,"courier appears at the actual store entry")
	check(app.world.front_door.position.distance_to(Vector3(3.2,0,2.85)) < .001 and app.world.courier.position.distance_to(app.world.front_door.position) < 1,"courier stands immediately outside supplied front doorway")
	for size in [Vector2i(480,800),Vector2i(960,1440),Vector2i(1600,2560)]:
		root.size = size; await process_frame; await process_frame
		check(app.courier_button.get_global_rect().intersection(app.get_global_rect()).size == app.courier_button.get_global_rect().size,"delivery button remains on screen %s"%size)
		check(app.courier_preview.visible and app.courier_viewport.find_world_3d() == app.viewport.find_world_3d() and app.world.courier.get_world_3d() == app.courier_viewport.find_world_3d(),"waiting preview renders the one authoritative shop world")
		check(is_equal_approx(app.world.camera.v_offset,-1.1),"waiting courier leaves normal service camera unchanged")
		for point in [app.world.courier.position,app.world.courier_label.position,app.world.courier_parcel.position]:
			var pixel: Vector2 = app.courier_camera.unproject_position(point)
			check(Rect2(Vector2(4,4),Vector2(app.courier_viewport.size)-Vector2(8,8)).has_point(pixel),"full courier/parcel contained in actual waiting inset %s"%size)

	var fake := FullscreenFixture.new(); app.add_child(fake); app.services = fake
	for tick in range(200):
		if app.model.state.active_task.is_empty(): break
		app.model.step(.05)
	check(app.model.queue_task("checkout",-1),"ordinary counter job occupies clerk before courier collection")
	app._courier_action()
	check(app.model.state.queued_task.get("kind","") == "collect_delivery","real courier button queues deliberate clerk movement behind actual job")
	await freeze_collection(app,fake,"queued")
	for tick in range(400):
		if app.model.state.active_task.get("kind","") == "collect_delivery": break
		app._process(.05)
	check(app.model.state.active_task.get("kind","") == "collect_delivery","queued door collection becomes actual clerk task")
	for size in [Vector2i(480,800),Vector2i(960,1440),Vector2i(1600,2560)]:
		root.size = size; await process_frame; await process_frame
		app.world.sync(app.model.state,0)
		var controls: Control = app.stock_buttons.apple.get_parent().get_parent().get_parent()
		var feet: Vector2 = app.world_container.get_global_transform()*app.world.camera.unproject_position(app.world.courier.position)
		var head: Vector2 = app.world_container.get_global_transform()*app.world.camera.unproject_position(app.world.courier_label.position)
		var parcel: Vector2 = app.world_container.get_global_transform()*app.world.camera.unproject_position(app.world.courier_parcel.position)
		var hud: Control = app.shift_label.get_parent().get_parent()
		print("COURIER_COLLECTION_GEOMETRY size=%s feet=%s head=%s parcel=%s HUD=%s controls=%s"%[size,feet,head,parcel,hud.get_global_rect(),controls.get_global_rect()])
		check(app.get_global_rect().has_point(feet) and feet.y < controls.get_global_rect().position.y-16 and head.y > hud.get_global_rect().end.y+16,"full active-collection silhouette between HUD and controls %s"%size)
		check(parcel.y < controls.get_global_rect().position.y-16 and parcel.y > hud.get_global_rect().end.y+16,"active parcel visible between HUD and controls %s"%size)
		check(is_equal_approx(app.world.camera.v_offset,-6.3),"door focus only during active collection")
	await freeze_collection(app,fake,"active")
	var stock_before: int = app.model.state.produced
	for tick in range(400):
		app._process(.05)
		if app.model.state.courier.collected == 1: break
	check(app.model.state.courier.collected == 1 and app.model.state.produced == stock_before+8*app.model.skus().size(),"resume completes one actual parcel handoff with exact stock")
	check(is_equal_approx(app.world.camera.v_offset,-1.1) and not app.world.courier.visible,"ordinary shop framing returns after handoff")
	app._shutdown_audio()
	var deadline: int = Time.get_ticks_usec()+int(clampf(AudioServer.get_time_to_next_mix()*3.0,.1,.25)*1000000.0)
	while Time.get_ticks_usec() < deadline: await process_frame
	app.queue_free(); await process_frame; await process_frame
