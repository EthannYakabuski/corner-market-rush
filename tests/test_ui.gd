extends SceneTree
## SOURCE FIXTURES ONLY: synthetic service events and isolated profile data.
## This creates no screenshots and is never evidence of a real SDK/native earn.
const Profile = preload("res://game/profile.gd")
var checks := 0
var app
var fake: FakeServices

class FakeServices extends Node:
	var active := false
	var callback := Callable()
	var rounds := 0
	var scores: Dictionary = {}
	var unlocked: Array = []
	func set_menu_visible(_value: bool) -> void: pass
	func menu_bottom_reserve(_reference: CanvasItem = null) -> float: return 0.0
	func fullscreen_ad_active() -> bool: return active
	func can_reward() -> bool: return true
	func reward_requested(_context: String, result: Callable) -> void: callback = result
	func round_finished() -> void: rounds += 1
	func unlock(key: String) -> void:
		if not key in unlocked: unlocked.append(key)
	func submit(key: String, score: int) -> void: scores[key] = maxi(score,int(scores.get(key,0)))
	func status() -> String: return "Isolated synthetic service fixture"
	func sign_in() -> void: pass
	func open_achievements() -> void: pass
	func open_leaderboards(_key: String = "") -> void: pass
	func privacy_options() -> void: pass

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	assert(condition,message)
	checks += 1

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found := find_button(child,text)
		if found != null: return found
	return null

func press(text: String) -> void:
	var button := find_button(app,text)
	check(button != null,"actual scene button exists: "+text)
	if button != null: button.pressed.emit()

func _run() -> void:
	check("--qa-isolated" in OS.get_cmdline_user_args(),"scene fixture requires explicit isolated profile flag")
	root.size = Vector2i(960,1440)
	var scene: PackedScene = load("res://scenes/main.tscn")
	app = scene.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	# Manual bounded scene ticks below remove OS scheduling from the assertions.
	app.set_process(false)
	fake = FakeServices.new()
	root.add_child(fake)
	app.services = fake
	app.profile.data = Profile.fresh()
	app.profile.data.tutorial_seen = true
	app.background = false
	check(app.screen == "home","scene opens on Home")
	check(app.world.shelves.size() == 6,"all six supplied shop fixtures instantiated")
	check(app.world.clerk.get_child_count() > 0,"real employee asset instantiated")
	check(app.world.products.greens.size() >= 8,"actual bag submodels support depletion")
	check(app.world.products.apple.size() == 6,"actual fruit geometry is six stock-visible children")
	app._start_shift(1)
	await process_frame
	check(app.stock_buttons.size() == 2,"tutorial has exactly two product controls")
	check(not app.paused,"ordinary source fixture starts ready")
	app._pause_shift("Fixture pause","No owner profile is used.")
	var elapsed := float(app.model.state.elapsed)
	app._process(0.2)
	check(is_equal_approx(float(app.model.state.elapsed),elapsed),"modal freezes actual scene model")
	check(app.world.frozen,"modal freezes actual customer animation players")
	press("Resume the shop")
	app._process(0.05)
	app._queue_task("restock","apple")
	app._queue_task("restock","bread")
	check(app.model.state.active_task.kind == "restock" and not app.model.state.queued_task.is_empty(),"scene has one active plus one genuine queued task")
	var run := str(app.model.state.run_id)
	var active: Dictionary = app.model.state.active_task.duplicate(true)
	app._back()
	check(app.paused and app.modal != null,"Back opens neutral pause")
	press("Save & Home")
	app._resume_saved()
	check(str(app.model.state.run_id) == run,"same fixture run resumes")
	check(app.model.state.active_task.target == active.target and app.model.state.queued_task.target == "bread","both clerk jobs survive cold-style restoration")
	check(app.paused and app.modal != null,"restored shift awaits explicit Resume")
	press("Resume the shop")
	var ticks := 0
	while app.model.state.status == "active" and ticks < 1800:
		var action: Dictionary = app.model.baseline_action()
		if not action.is_empty(): app._queue_task(action.kind,action.target)
		app._process(0.1)
		ticks += 1
	check(app.model.state.status == "won","actual scene completes first shift via ordinary restock and checkout tasks")
	check(int(app.model.state.restocks) > 0 and int(app.model.state.checkouts) == 4,"scene completed both central service actions")
	check(app.result_banked and app.modal != null,"scene presents saved result")
	var coins := int(app.profile.data.coins)
	var xp := int(app.profile.data.xp)
	check(coins > 0 and xp > 0,"scene earned money and XP")
	check(fake.rounds == 1,"natural stopped round cadence called once")
	app._settle_shift()
	check(int(app.profile.data.coins) == coins and int(app.profile.data.xp) == xp and fake.rounds == 1,"reopening result cannot duplicate bank or ad cadence")
	var cold := Profile.new(app.profile.file_path)
	check(cold.load_profile(),"actual scene's isolated profile reloads")
	check(int(cold.data.coins) == coins and int(cold.data.xp) == xp and cold.data.completed.has("1"),"cold source profile retains exact settled totals")
	app.show_home()
	app.show_achievements()
	await process_frame
	check(app.catalog.achievements.size() == 20 and app.catalog.leaderboards.size() == 3,"all public symbolic mappings reachable")
	app.show_daily()
	check(app.content.get_child_count() > 8,"calendar, basket and three daily goals reachable")
	app.show_growth()
	check(app.profile.data.upgrades.size() == 3,"all improvement types reachable")
	# Synthetic callback/endcard fixture: main handler, model aid and neutral Resume.
	app._start_shift(2)
	app._process(0.1)
	app._request_reserve()
	press("Keep playing")
	check(not app.reward_pending and not app.model.state.reward_used,"decline never grants a reserve")
	app._request_reserve()
	press("Request earned reserve")
	check(app.reward_pending and app.paused,"pending is set before requesting the service")
	fake.active = true
	var before_reserve: Dictionary = app.model.state.reserve.duplicate(true)
	elapsed = float(app.model.state.elapsed)
	fake.callback.call(true)
	app._process(10)
	check(app.model.state.reward_used and app.model.state.assisted,"true synthetic earned callback invokes the actual one-use handler")
	for sku in before_reserve:
		check(int(app.model.state.reserve[sku]) == int(before_reserve[sku])+3,"actual earned handler adds exactly three reserve: "+sku)
	check(is_equal_approx(float(app.model.state.elapsed),elapsed) and app.paused,"earned-before-dismissal cannot resume behind endcard")
	fake.callback.call(true)
	app._process(0.2)
	for sku in before_reserve:
		check(int(app.model.state.reserve[sku]) == int(before_reserve[sku])+3,"duplicate synthetic earned remains once-only: "+sku)
	fake.active = false
	app._process(0.1)
	check(app.paused and app.modal != null,"dismissal waits for explicit neutral Resume")
	check(is_equal_approx(float(app.model.state.elapsed),elapsed),"endcard dismissal frame does not advance shop")
	press("Resume the shop")
	app._process(0.1)
	check(float(app.model.state.elapsed) > elapsed,"only explicit Resume restarts shop time")
	# Unearned/cancelled settlement is separate from the earned fixture.
	app._start_shift(2)
	app._process(0.1)
	app._request_reserve()
	press("Request earned reserve")
	fake.active = true
	before_reserve = app.model.state.reserve.duplicate(true)
	fake.callback.call(false)
	fake.active = false
	app._process(0.1)
	check(not app.model.state.reward_used and app.model.state.reserve == before_reserve,"unearned close changes no reserve")
	check(app.paused,"unearned close also needs neutral Resume")
	press("Resume the shop")
	# A callback belonging to an obsolete run must never affect a replacement.
	app._request_reserve()
	press("Request earned reserve")
	var stale := fake.callback
	app._start_shift(3)
	before_reserve = app.model.state.reserve.duplicate(true)
	stale.call(true)
	app._process(0.1)
	check(not app.model.state.reward_used and app.model.state.reserve == before_reserve,"stale earned callback cannot alter replacement run")
	# Background/focus recovery preserves state and requires a deliberate return.
	app.ad_waiting = false
	app.reward_pending = false
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	elapsed = float(app.model.state.elapsed)
	app._process(5)
	check(is_equal_approx(float(app.model.state.elapsed),elapsed),"background preserves exact shop time")
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	app._process(0.1)
	check(app.paused,"focus return never silently advances time")
	app.show_home()
	app._shutdown_audio()
	app.queue_free()
	fake.queue_free()
	await process_frame
	await process_frame
	print("MARKET UI/LIFECYCLE: %d checks passed; isolated scene/synthetic service fixtures, NOT native evidence" % checks)
	quit(0)
