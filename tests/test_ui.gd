extends SceneTree
## SOURCE FIXTURES ONLY: synthetic service events and isolated profile data.
## This creates no screenshots and is never evidence of a real SDK/native earn.
const Profile = preload("res://game/profile.gd")
var checks := 0
var failures := 0
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
	checks += 1
	if not condition:
		failures += 1
		push_error("Assertion failed: "+message)

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

func inside_app(control: Control) -> bool:
	if not is_instance_valid(control): return false
	var outer: Rect2 = app.get_global_rect()
	var inner := control.get_global_rect()
	return inner.position.x >= outer.position.x-1 and inner.position.y >= outer.position.y-1 and inner.end.x <= outer.end.x+1 and inner.end.y <= outer.end.y+1

func touch_dp(control: Control, density: float) -> Vector2:
	# This transform includes the actual viewport/canvas/window stretch. Density
	# belongs to the named emulated profile, not the Windows host display.
	var transform := control.get_screen_transform()
	var origin := transform*Vector2.ZERO
	var physical := Vector2((transform*Vector2(control.size.x,0)-origin).length(),(transform*Vector2(0,control.size.y)-origin).length())
	return physical*160.0/density

func geometry(profile_name: String, dimensions: Vector2i, density: float) -> void:
	root.size = dimensions
	app.show_home()
	await process_frame
	await process_frame
	var header_panel: Control = app.header.get_parent().get_parent()
	check(header_panel.size.y <= 150,"header bounded height on "+profile_name)
	check(app.header.size.x >= 160 and app.header.get_line_count() == 2,"wallet is readable two-line text, never a one-letter column: "+profile_name)
	check(inside_app(find_button(app,"Open the shop  ·  Shift %d" % app.profile.available_shift())),"primary Open control inside viewport: "+profile_name)
	# Financial stress is an isolated presentation fixture, not a grant or save.
	var prior: Dictionary = app.profile.data.duplicate(true)
	app.profile.data.coins = 99999999
	app.profile.data.xp = 999999
	app._refresh_header()
	await process_frame
	check(app.header.get_line_count() == 2 and header_panel.size.y <= 150,"large wallet values cannot expand header: "+profile_name)
	app.profile.data = prior
	app._start_shift(31,true)
	await process_frame
	await process_frame
	check(app.stock_buttons.size() == 6,"full product controls present: "+profile_name)
	for sku in app.stock_buttons:
		check(ResourceLoader.exists(app._product_icon_path(str(sku))),"actual runtime product pictogram imported: "+str(sku))
		check(inside_app(app.stock_buttons[sku]),"product action inside viewport: "+profile_name+"/"+str(sku))
		var dp := touch_dp(app.stock_buttons[sku],density)
		if sku == "apple":
			var control: Control = app.stock_buttons[sku]
			print("TOUCH_GEOMETRY %s: window=%s app=%s viewport=%s control=%s screen_transform=%s dp=%s density=%s" % [profile_name,root.size,app.size,app.get_viewport_rect().size,control.size,control.get_screen_transform(),dp,density])
		check(dp.x >= 48 and dp.y >= 48-0.01,"product action meets48dp in actual canvas scale: "+profile_name+"/"+str(sku))
	for button in app.customer_buttons.values():
		if not button.is_visible_in_tree(): continue
		var dp := touch_dp(button,density)
		check(inside_app(button) and dp.x >= 48 and dp.y >= 48,"whole customer checkout target is reachable48dp: "+profile_name)
		check(button.get_signal_connection_list("pressed").size() == 1,"whole checkout card has only one action handler: "+profile_name)
	check(inside_app(find_button(app,"Pause")),"Pause remains reachable: "+profile_name)
	check(app.shift_label.get_global_rect().end.y < app.stock_buttons.apple.get_global_rect().position.y-220,"shop has visible space between HUD and actions: "+profile_name)
	app.show_home()

func _run() -> void:
	var isolated := "--qa-isolated" in OS.get_cmdline_user_args()
	check(isolated,"scene fixture requires explicit isolated profile flag")
	if not isolated:
		quit(1)
		return
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
	await geometry("phone",Vector2i(1080,1920),420)
	await geometry("seven-inch logical profile",Vector2i(1200,1920),320)
	await geometry("ten-inch logical profile",Vector2i(1600,2560),300)
	root.size = Vector2i(960,1440)
	app.profile.data = Profile.fresh()
	app.profile.data.tutorial_seen = true
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
	print("MARKET UI/LIFECYCLE %s: %d checks, %d failures; isolated scene/synthetic service fixtures, NOT native evidence" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(0 if failures == 0 else 1)
