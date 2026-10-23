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
	if node.is_queued_for_deletion(): return null
	if node is Button and node.text == text and node.is_visible_in_tree(): return node
	for child in node.get_children():
		var found := find_button(child,text)
		if found != null: return found
	return null

func press(text: String) -> void:
	var button := find_button(app,text)
	check(button != null,"actual scene button exists: "+text)
	if button != null: button.pressed.emit()

func inside_app(control: Control) -> bool:
	return inside_control(control,app)

func inside_control(control: Control, container: Control) -> bool:
	if not is_instance_valid(control) or not is_instance_valid(container): return false
	var outer: Rect2 = container.get_global_rect()
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
	app._notice("Menu notice fixture")
	check(app.footer.text == "Menu notice fixture","menu notices still use the existing footer: "+profile_name)
	# Financial stress is an isolated presentation fixture, not a grant or save.
	var prior: Dictionary = app.profile.data.duplicate(true)
	app.profile.data.coins = 99999999
	app.profile.data.xp = 999999
	app._refresh_header()
	await process_frame
	check(app.header.get_line_count() == 2 and header_panel.size.y <= 150,"large wallet values cannot expand header: "+profile_name)
	app.profile.data = prior
	# Authored shift29 starts with an actual maximum three-product basket and
	# all six shelves. Advance its model so customer checks cannot be vacuous.
	app._start_shift(29,true)
	app._process(0.1)
	app._refresh_game()
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
	var tested_customers := 0
	var maximum_basket := 0
	for id in app.customer_buttons:
		var button: Button = app.customer_buttons[id]
		if not button.is_visible_in_tree(): continue
		tested_customers += 1
		var card: Dictionary = app.customer_cards[id]
		maximum_basket = maxi(maximum_basket,card.amounts.size())
		var dp := touch_dp(button,density)
		check(inside_app(button) and dp.x >= 48 and dp.y >= 48,"whole customer checkout target is reachable48dp: "+profile_name)
		check(button.get_signal_connection_list("pressed").size() == 1,"whole checkout card has only one action handler: "+profile_name)
		check(inside_control(card.action_panel,button) and inside_control(card.action_panel,app.customer_row.get_parent()),"checkout footer fully inside card and scroll clip: "+profile_name)
		check(inside_control(card.action_text,card.action_panel) and card.action_text.get_line_count() == 1,"checkout instruction fully visible on one line: "+profile_name)
		for sku in card.amounts:
			var amount: Label = card.amounts[sku]
			var product_name: Label = card.product_names[sku]
			var product_row: Control = card.product_rows[sku]
			check(amount.get_line_count() == 1 and amount.size.x >= 48 and inside_control(amount,product_row),"basket quantity remains a bounded single line: "+profile_name+"/"+str(sku))
			check(product_name.text == str(app.catalog.products[sku].name) and product_name.get_line_count() == 1 and product_name.size.x >= 96 and inside_control(product_name,product_row),"basket product name is readable next to pictogram: "+profile_name+"/"+str(sku))
			check(product_name.get_global_rect().end.x <= amount.get_global_rect().position.x and inside_control(product_row,button),"basket name/count never overlap or leave card: "+profile_name+"/"+str(sku))
	check(tested_customers > 0 and maximum_basket == 3,"actual maximum three-product basket was laid out: "+profile_name)
	check(inside_app(find_button(app,"Pause")),"Pause remains reachable: "+profile_name)
	check(app.shift_label.get_global_rect().end.y < app.stock_buttons.apple.get_global_rect().position.y-220,"shop has visible space between HUD and actions: "+profile_name)
	# This actual once-only message was clipped off the right edge on Android.
	# Exercise its real nonblocking toast branch, including an existing modal.
	app._pause_shift("Notice geometry","The scene and isolated draft remain paused.")
	var notice_modal: Control = app.modal
	var notice_text := "A reserve delivery is available once per ordinary shift after the first."
	app._notice(notice_text)
	var toast: Label = null
	for child in app.get_children():
		if child is Label and child.text == notice_text: toast = child
	check(toast != null,"actual gameplay notice creates a visible text control: "+profile_name)
	await process_frame
	await process_frame
	if toast != null:
		check(inside_app(toast) and toast.get_global_rect().position.x >= app.get_global_rect().position.x+16 and toast.get_global_rect().end.x <= app.get_global_rect().end.x-16,"whole gameplay notice stays inside both viewport margins: "+profile_name)
		check(toast.get_line_count() > 0 and toast.get_visible_line_count() == toast.get_line_count(),"wrapped notice text is vertically complete: "+profile_name)
		check(toast.mouse_filter == Control.MOUSE_FILTER_IGNORE and app.modal == notice_modal and notice_modal.is_visible_in_tree() and find_button(app,"Resume the shop") != null,"notice neither replaces the pause modal nor intercepts Resume: "+profile_name)
		toast.queue_free()
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
	app.show_home()
	await process_frame
	await process_frame
	var old_open: Button = find_button(app,"Open the shop  ·  Shift 1")
	var retired_page_children: Array = app.page.get_children()
	press("Open the shop  ·  Shift 1")
	check(is_instance_valid(old_open) and old_open.is_inside_tree() and not old_open.is_visible_in_tree(),"pressed page control stays in tree while hidden until dispatch finishes")
	for retired in retired_page_children:
		check(retired.is_inside_tree() and retired.is_queued_for_deletion() and retired.process_mode == Node.PROCESS_MODE_DISABLED,"retired page stays attached but cannot process another action")
	await process_frame
	await process_frame
	check(not is_instance_valid(old_open),"old pressed page is freed after dispatch")
	check(app.stock_buttons.size() == 2,"tutorial has exactly two product controls")
	check(not app.paused,"ordinary source fixture starts ready")
	app._pause_shift("Fixture pause","No owner profile is used.")
	var elapsed := float(app.model.state.elapsed)
	app._process(0.2)
	check(is_equal_approx(float(app.model.state.elapsed),elapsed),"modal freezes actual scene model")
	check(app.world.frozen,"modal freezes actual customer animation players")
	var retired_modal: Control = app.modal
	press("Resume the shop")
	check(retired_modal.is_inside_tree() and not retired_modal.visible and retired_modal.is_queued_for_deletion() and retired_modal.process_mode == Node.PROCESS_MODE_DISABLED,"pressed modal stays attached and inert until dispatch finishes")
	await process_frame
	await process_frame
	check(not is_instance_valid(retired_modal),"old pressed modal frees after dispatch")
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
	# Propagate exactly as Android does: Node locks its child list while the
	# notification visits this scene. Direct _notification calls miss that lock.
	app.ad_waiting = false
	app.reward_pending = false
	app._close_modal()
	var pause_additions: Array[int] = [0]
	var count_pause := func(child: Node):
		if child is ColorRect: pause_additions[0] += 1
	app.child_entered_tree.connect(count_pause)
	elapsed = float(app.model.state.elapsed)
	app.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	app.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(app.paused and app.model.state.paused and app.world.frozen,"propagated background freezes simulation and actors immediately")
	check(app.modal == null and pause_additions[0] == 0,"propagated notification never adds children while the tree is locked")
	check(bool(app.profile.data.active.model.state.paused) and is_equal_approx(float(app.profile.data.active.model.state.elapsed),elapsed),"background persists the exact paused draft before deferred UI")
	app._process(5)
	check(is_equal_approx(float(app.model.state.elapsed),elapsed),"background preserves exact shop time")
	await process_frame
	check(app.modal != null and pause_additions[0] == 1,"duplicate pause/focus notifications create exactly one usable deferred modal")
	press("Resume the shop")
	check(app.paused and app.modal != null,"Resume cannot close the pause while application remains backgrounded")
	app.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	app.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	app._process(0.1)
	check(app.paused and is_equal_approx(float(app.model.state.elapsed),elapsed),"foreground return never silently advances time")
	press("Resume the shop")
	app._process(0.2)
	check(not app.paused and not app.model.state.paused and float(app.model.state.elapsed) > elapsed,"explicit foreground Resume advances the actual model")
	# A queued notification belongs only to its captured model/run and page.
	app.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	app.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	app._start_shift(3)
	var replacement_run := str(app.model.state.run_id)
	await process_frame
	check(app.modal == null and not app.paused and str(app.model.state.run_id) == replacement_run,"deferred pause cannot attach to a replacement run")
	app.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	app.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	app.show_home()
	await process_frame
	check(app.screen == "home" and app.modal == null,"deferred pause cannot appear after leaving the game")
	app._start_shift(3)
	app.child_entered_tree.disconnect(count_pause)
	# Linux verbose diagnostics identified owned WAV/Ogg playbacks surviving
	# fast frame-only teardown. Keep their owner alive for bounded mixer time.
	var owned_stream_paths: Array[String] = []
	if is_instance_valid(app.music) and app.music.stream != null:
		owned_stream_paths.append(str(app.music.stream.resource_path))
	for player in app.effects:
		if is_instance_valid(player) and player.stream != null:
			owned_stream_paths.append(str(player.stream.resource_path))
	check(not owned_stream_paths.is_empty(),"audio teardown exercises actual owned streams before shutdown")
	print("MARKET_UI_TEARDOWN owned_stream_paths=%s time_to_next_mix=%s" % [owned_stream_paths,AudioServer.get_time_to_next_mix()])
	app.set_process(false)
	app._shutdown_audio()
	var drain_seconds: float = clampf(AudioServer.get_time_to_next_mix()*3.0,0.1,0.25)
	var deadline_us: int = Time.get_ticks_usec()+int(drain_seconds*1000000.0)
	while Time.get_ticks_usec() < deadline_us:
		await process_frame
	await process_frame
	# Check teardown invalidation only after observing/draining the original
	# owner's audio, so this lifecycle case cannot vacate the audio regression.
	app.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	root.remove_child(app)
	await process_frame
	check(app.pending_pause_ui.is_empty() and app.modal == null,"tree exit invalidates pending pause UI without adding detached controls")
	app.queue_free()
	fake.queue_free()
	await process_frame
	await process_frame
	print("MARKET UI/LIFECYCLE %s: %d checks, %d failures; isolated scene/synthetic service fixtures, NOT native evidence" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(0 if failures == 0 else 1)
