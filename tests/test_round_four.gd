extends SceneTree
## Isolated source fixtures only; never native progress, SDK rewards or screenshots.
const Model = preload("res://game/market_model.gd")
const Profile = preload("res://game/profile.gd")
var checks = 0
var failures = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("Assertion failed: "+label)
func _initialize() -> void: _run.call_deferred()
func fresh(shift_id: int = 1, ranks: Dictionary = {}) -> RefCounted:
	var m = Model.new(); m.new_shift(shift_id,false,ranks); return m
func _run() -> void:
	if "--qa-isolated" not in OS.get_cmdline_user_args(): push_error("Round Four test requires isolated QA storage"); quit(1); return
	for key in Profile.SERVICE_UPGRADES:
		for rank in [0,1,3]:
			var p = Profile.new("user://qa_market_r4/"+key+str(rank)+".json")
			p.data.coins = 10000
			for tier in range(rank): check(p.buy_upgrade(key),"service tier purchases save: "+key+str(tier))
			var m = fresh(36,p.data.upgrades)
			var kind = "checkout" if key == "checkout" else "restock"
			var target: Variant = -1 if kind == "checkout" else key.trim_prefix("restock_")
			if kind == "restock": m.state.shelves[target] = 0; m.state.reserve[target] = 20
			check(m.queue_task(kind,target),"new service job accepted: "+key+str(rank))
			check(is_equal_approx(m.state.active_task.interaction_duration,(1.1 if kind == "checkout" else 1.0)/(1+.25*rank)),"correct per-service interaction speed: "+key+str(rank))
			for other in Model.SERVICE_KEYS:
				check(int(m.state.service_ranks[other]) == (rank if other == key else 0),"upgrade remains product-specific: "+key+"/"+other)
			if rank == 3:
				var coins: int = p.data.coins
				check(not p.buy_upgrade(key) and int(p.data.coins) == coins,"service rank cap cannot debit coins again: "+key)
	# Real legacy schema fixture: no service keys, but existing bank and upgrades remain.
	var p = Profile.new("user://qa_market_r4/legacy.json")
	p.data.coins = 423; p.data.xp = 135; p.data.upgrades.capacity = 2
	for key in Profile.SERVICE_UPGRADES: p.data.upgrades.erase(key)
	check(p.save(),"legacy v1 fixture remains valid")
	var loaded = Profile.new(p.file_path)
	check(loaded.load_profile() and loaded.data.coins == 423 and loaded.data.xp == 135 and loaded.data.upgrades.capacity == 2,"loading adds speed options without resetting banked profile")
	for key in Profile.SERVICE_UPGRADES:
		check(loaded.data.upgrades[key] == 0,"legacy service rank defaults zero: "+key)
		var invalid = loaded.data.duplicate(true); invalid.upgrades[key] = 4
		check(not loaded._valid(invalid),"new speed rank validation rejects over-cap: "+key)
	var m = fresh()
	check(m.state.customers[0].phase == "shopping" and m.queue_task("checkout",-1),"counter job can be queued before any complete basket")
	check(not m.queue_task("checkout",-1),"same standby cannot occupy both task slots")
	for tick in range(10): m.step(.05)
	check(m.state.active_task.motion_phase == "wait" and int(m.state.served) == 0 and int(m.state.revenue) == 0,"clerk waits at counter without paying an incomplete basket")
	var snapshot = m.snapshot(); var resumed = Model.new()
	check(resumed.restore(snapshot) and resumed.snapshot() == snapshot,"counter standby snapshot restores exactly")
	m.set_paused(true); var elapsed: float = m.state.elapsed; m.step(.25)
	check(is_equal_approx(m.state.elapsed,elapsed) and int(m.state.served) == 0,"pause freezes counter standby and customers")
	m.set_paused(false)
	for tick in range(500):
		m.step(.05)
		if int(m.state.served) == 1: break
	check(m.state.served == 1 and m.state.revenue == 4 and m.state.active_task.is_empty(),"one explicit standby checks out first real completed basket exactly once")
	check(m.state.customers[0].paid and m.state.customers[0].happy,"untroubled high-patience visit earns a happy departure")
	for tick in range(300): m.step(.05)
	check(m.state.served == 1 and m.state.revenue == 4,"standby is one customer, never an indefinite automatic cashier")
	m = fresh(); check(m.queue_task("restock","apple") and m.queue_task("checkout",-1),"checkout can wait behind a shelf job before any basket arrives")
	check(m.cancel_queued() and m.state.queued_task.is_empty(),"queued counter visit can be cancelled normally")
	m = fresh(); m.queue_task("checkout",-1)
	for tick in range(8): m.step(.05)
	check(m.queue_task("restock","apple"),"new shelf job can queue behind empty counter wait")
	m.step(.05)
	check(m.state.active_task.kind == "restock" and m.state.queued_task.is_empty(),"empty-counter standby yields to deliberate shelf work without deadlock")
	# Legacy active draft gets only optional defaults; existing task/stock remain.
	m = fresh(); var old = m.snapshot(); old.state.erase("service_ranks")
	for customer in old.state.customers:
		for key in ["stock_waiting","waited_for_stock","happy"]: customer.erase(key)
	resumed = Model.new()
	check(resumed.restore(old) and resumed.state.run_id == m.state.run_id and resumed.state.shelves == m.state.shelves,"legacy active shift restores without replacing its genuine run identity/stock")
	for key in Model.SERVICE_KEYS: check(resumed.state.service_ranks[key] == 0,"legacy active shift speed unchanged: "+key)
	# Explicit stockout fixture, separate from legal completion above.
	m = fresh(); var c: Dictionary = m.state.customers[0]
	m.state.shelves.apple = 0; m.state.reserve.apple += 1
	c.position = [-2.35,-.3]; c.route = []; c.motion_phase = "interact"; c.pick_timer = .5
	m.step(.05)
	check(c.stock_waiting and c.waited_for_stock,"empty shelf produces immediate persistent stockout history")
	m.state.shelves.apple = 1; m.state.reserve.apple -= 1; m.step(.05)
	check(not c.stock_waiting and c.waited_for_stock,"restocking clears current exclamation but preserves visit history")
	await _test_scene()
	print("MARKET ROUND FOUR CHECKS %d failures %d; source fixtures only"%[checks,failures])
	quit(1 if failures else 0)
func _test_scene() -> void:
	AudioServer.set_bus_mute(0,true) # This process only; no auditory-validation claim.
	root.size = Vector2i(960,1440)
	var app = load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	await process_frame; await process_frame
	app.set_process(false); app.services = null
	app.profile.data = Profile.fresh(); app.profile.data.tutorial_seen = true; app.background = false
	app._start_shift(1)
	await process_frame; await process_frame
	check(app.checkout_button.text == "Go to checkout" and app.checkout_button.visible and not app.checkout_button.disabled,"visible ordinary counter action exists without a ready customer")
	app.checkout_button.pressed.emit()
	check(app.model.state.active_task.target == -1,"counter action dispatches actual scene/model standby")
	var c: Dictionary = app.model.state.customers[0]
	app.model.state.shelves.apple = 0; app.model.state.reserve.apple += 1
	c.position = [-2.35,-.3]; c.route = []; c.motion_phase = "interact"; c.pick_timer = .5
	app.model.step(.05); app.world.sync(app.model.state,0)
	var emote: Sprite3D = app.world.actor_emotes[0]
	check(emote.visible and emote.texture.resource_path.ends_with("emote_exclamation.png"),"actual 3D customer shows supplied Kenney exclamation")
	check(emote.position.y > app.world.actor_labels[0].position.y and is_equal_approx(emote.pixel_size*emote.texture.get_width(),.55),"emote is readable above name/head at consistent world size")
	c.phase = "served"; c.happy = true; c.stock_waiting = false; c.motion_phase = "celebrate"
	app.world.sync(app.model.state,0)
	check(emote.visible and emote.texture.resource_path.ends_with("emote_faceHappy.png"),"actual satisfied departure shows supplied happy-face texture")
	c.motion_phase = "exited"; app.world.sync(app.model.state,0)
	check(not emote.visible,"departed NPC does not leave a floating emote")
	app.show_growth(); await process_frame; await process_frame
	check(app.profile.data.upgrades.size() == 10,"growth retains existing three options plus seven service options")
	app._shutdown_audio()
	var deadline: int = Time.get_ticks_usec()+int(clampf(AudioServer.get_time_to_next_mix()*3.0,.1,.25)*1000000.0)
	while Time.get_ticks_usec() < deadline: await process_frame
	app.queue_free(); await process_frame; await process_frame
