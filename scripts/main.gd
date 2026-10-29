extends Control
const Model = preload("res://game/market_model.gd")
const Profile = preload("res://game/profile.gd")
const World = preload("res://scripts/shop_world.gd")
const INK := Color("243e47")
const CREAM := Color("fff2da")
const TEAL := Color("267f79")
const CORAL := Color("ce6b58")
var catalog: Dictionary = {}
var profile: Profile
var model: Model
var world: World
var services: Node
var viewport: SubViewport
var world_container: SubViewportContainer
var ui: MarginContainer
var page: VBoxContainer
var content: VBoxContainer
var header: Label
var footer: Label
var modal: ColorRect
var screen := "home"
var paused := false
var background := false
var reward_pending := false
var ad_waiting := false
var reward_token := ""
var daily_mode := false
var daily_day := ""
var auto_save := 0.0
var refresh_clock := 0.0
var stock_buttons: Dictionary = {}
var customer_buttons: Dictionary = {}
var customer_cards: Dictionary = {}
var customer_row: HBoxContainer
var checkout_button: Button
var courier_button: Button
var courier_status: Label
var courier_preview: SubViewportContainer
var courier_viewport: SubViewport
var courier_camera: Camera3D
var basket_label: Label
var task_label: Label
var shift_label: Label
var shift_progress: ProgressBar
var task_progress: ProgressBar
var music: AudioStreamPlayer
var effects: Array = []
var music_key := ""
var sound_clock := 0.0
var result_banked := false
var settle_error := false
var pause_ui_generation := 0
var pending_pause_ui: Dictionary = {}

func _ready() -> void:
	get_tree().auto_accept_quit = false
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://game/catalog.json"))
	var path := "user://qa_market/profile.json" if "--qa-isolated" in OS.get_cmdline_user_args() else Profile.SAVE_FILE
	profile = Profile.new(path)
	profile.load_profile()
	profile.roll_day(Profile.today())
	services = get_node_or_null("/root/Services")
	_build_audio()
	_build_view()
	if services != null:
		services.menu_bottom_reserve_changed.connect(_fit_safe_area)
		services.service_notice.connect(_notice)
	resized.connect(_fit_safe_area)
	show_home()
	if not profile.recovery_notice.is_empty():
		_notice(profile.recovery_notice)

func _build_audio() -> void:
	for bus_name in ["Music", "Effects"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus_name)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.volume_db = -16
	add_child(music)
	for index in range(4):
		var player := AudioStreamPlayer.new()
		player.bus = "Effects"
		player.volume_db = -6
		add_child(player)
		effects.append(player)
	_audio_settings()

func _audio_settings() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),not bool(profile.data.music))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Effects"),not bool(profile.data.effects))

func _music(key: String) -> void:
	if music_key == key: return
	music_key = key
	var path := "res://assets/audio/music/%s.wav" % key
	if ResourceLoader.exists(path):
		music.stream = load(path)
		music.play()

func _sfx(key: String) -> void:
	if background or reward_pending or (services != null and services.fullscreen_ad_active()): return
	var path := "res://assets/audio/sfx/%s.ogg" % key
	if not ResourceLoader.exists(path): return
	for player in effects:
		if not player.playing:
			player.volume_db = -16 if key == "footstep" else -6
			player.stream = load(path)
			player.play()
			return

func _build_view() -> void:
	world_container = SubViewportContainer.new()
	world_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world_container.stretch = true
	world_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world_container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(960,1440)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.own_world_3d = true
	world_container.add_child(viewport)
	world = World.new()
	viewport.add_child(world)
	world.setup(catalog)
	world.set_decor(int(profile.data.upgrades.decor))
	world.target_selected.connect(_queue_task)
	ui = MarginContainer.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	page = VBoxContainer.new()
	page.add_theme_constant_override("separation",14)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(page)
	_fit_safe_area()

func _fit_safe_area() -> void:
	if ui == null: return
	var top := 22
	var bottom := 20
	if OS.get_name() == "Android":
		var safe := DisplayServer.get_display_safe_area()
		var window := DisplayServer.window_get_size()
		if window.y > 0:
			top = maxi(top,int(float(safe.position.y)/window.y*size.y))
			bottom = maxi(bottom,int(float(window.y-safe.end.y)/window.y*size.y))
	if services != null and screen == "home":
		bottom += int(ceil(services.menu_bottom_reserve(self)))
	ui.add_theme_constant_override("margin_left",24)
	ui.add_theme_constant_override("margin_right",24)
	ui.add_theme_constant_override("margin_top",top)
	ui.add_theme_constant_override("margin_bottom",bottom)

func _style(color: Color, radius: int=22) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _panel(parent: Node, color: Color=CREAM) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",_style(color))
	parent.add_child(panel)
	return panel

func _vbox(parent: Node, separation: int=12) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",separation)
	parent.add_child(box)
	return box

func _row(parent: Node, separation: int=12) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",separation)
	parent.add_child(row)
	return row

func _text(parent: Node, value: String, font_size: int=26, color: Color=INK) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, action: Callable, color: Color=TEAL) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 76
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",26)
	button.add_theme_color_override("font_color",Color("fff9ea"))
	button.add_theme_color_override("font_disabled_color",Color("7b8d8c"))
	button.add_theme_stylebox_override("normal",_style(color,16))
	button.add_theme_stylebox_override("hover",_style(color.lightened(0.12),16))
	button.add_theme_stylebox_override("pressed",_style(color.darkened(0.16),16))
	button.add_theme_stylebox_override("disabled",_style(Color("d7dfd2"),16))
	button.pressed.connect(func():
		_sfx("click")
		action.call())
	parent.add_child(button)
	return button

func _spacer(parent: Node, ratio: float=1) -> Control:
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = ratio
	parent.add_child(spacer)
	return spacer

func _page(name_value: String, subtitle: String) -> void:
	pending_pause_ui.clear()
	screen = name_value
	for child in page.get_children():
		# A pressed control must stay in the tree until GUI dispatch returns.
		if child is Control:
			child.hide()
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		child.process_mode = Node.PROCESS_MODE_DISABLED
		child.queue_free()
	stock_buttons.clear()
	customer_buttons.clear()
	customer_cards.clear()
	footer = null
	var top := _row(_panel(page,Color("f7eace")))
	var title := _vbox(top,0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text(title,"CORNER MARKET RUSH",30,TEAL)
	_text(title,subtitle,21)
	header = _text(top,"",23)
	header.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.custom_minimum_size = Vector2(170,56)
	header.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_refresh_header()
	if services != null: services.set_menu_visible(screen == "home")
	_fit_safe_area()

func _refresh_header() -> void:
	if is_instance_valid(header):
		var coins := int(profile.data.coins)
		var amount := "%.1fm" % (float(coins)/1000000) if coins >= 1000000 else "%.1fk" % (float(coins)/1000) if coins >= 10000 else str(coins)
		header.text = "Level %d\n%s coins" % [profile.level(),amount]

func show_home() -> void:
	_close_modal()
	paused = true
	model = null
	daily_mode = false
	world.set_home()
	world.set_decor(int(profile.data.upgrades.decor))
	world.set_frozen(false)
	_page("home","A little shop. A lively rush.")
	_spacer(page,1)
	var panel := _panel(page,Color("fff2daeF"))
	var box := _vbox(panel)
	_text(box,"Fresh things. Familiar faces.",38,TEAL)
	_text(box,"Stock smart, serve with care, and grow the corner everyone knows.",26)
	if not profile.data.active.is_empty():
		_button(box,"Resume your saved shift",_resume_saved,CORAL)
	_button(box,"Open the shop  ·  Shift %d" % profile.available_shift(),func(): _confirm_start(profile.available_shift()),CORAL if profile.data.active.is_empty() else TEAL)
	var row := _row(box)
	_button(row,"The neighborhood",show_campaign)
	_button(row,"Daily baskets",show_daily)
	row = _row(box)
	_button(row,"Shop improvements",show_growth)
	_button(row,"Our regulars",show_journal)
	row = _row(box)
	_button(row,"Badges & records",show_achievements)
	_button(row,"Settings",show_settings,Color("6e8787"))
	footer = _text(box,"36 authored shifts · Unlimited ordinary retries · Offline local progress",19)
	_music("menu")

func _menu(title: String, subtitle: String) -> VBoxContainer:
	_close_modal()
	paused = true
	_page("menu",title)
	var panel := _panel(page,Color("fff2daf5"))
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var outer := _vbox(panel)
	var row := _row(outer)
	_text(row,title,38,TEAL).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(row,"Home",show_home,Color("6e8787")).custom_minimum_size.x = 140
	_text(outer,subtitle,24)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	content = _vbox(scroll,16)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return content

func _stars(parent: Node, value: int) -> void:
	var row := _row(parent,5)
	for index in range(3):
		var image := TextureRect.new()
		image.texture = load("res://assets/ui/star.png" if index < value else "res://assets/ui/star_outline.png")
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(32,32)
		row.add_child(image)

func show_campaign() -> void:
	var box := _menu("The neighborhood","One small shift at a time. Any completed shift can be replayed.")
	var manifest := Model.new()
	for chapter in range(6):
		var theme: Dictionary = catalog.themes[chapter]
		_text(box,theme.name,32,Color(theme.color))
		_text(box,theme.subtitle,23)
		for id in range(chapter*6+1,chapter*6+7):
			var definition: Dictionary = manifest.shifts[id-1]
			var row := _row(box)
			var button := _button(row,"%02d  %s" % [id,definition.title],func(): _confirm_start(id),Color(theme.color))
			button.disabled = id > profile.available_shift()
			_stars(row,int(profile.data.stars.get(str(id),0)))
		_button(box,"Practice this neighborhood · no timer or rewards",func(): _confirm_start(chapter*6+1,true),Color("758a80"))

func show_growth() -> void:
	var box := _menu("Shop improvements","Small improvements, meaningful choices. Every shift is possible without upgrades.")
	_text(box,"Manager level %d" % profile.level(),34,TEAL)
	_text(box,"%d XP · Next level at %d XP" % [int(profile.data.xp),Profile.xp_for_level(profile.level()+1)],25)
	var improvements := [{"key":"capacity","name":"Room on the shelf","description":"+1 shelf capacity per product, each tier."},{"key":"reserve","name":"A well-packed reserve","description":"+2 reserve items per product, each tier."},{"key":"decor","name":"A brighter little corner","description":"Add welcome decorations and celebrate your shop."}]
	for sku in Model.SKU_NAMES:
		improvements.append({"key":"restock_"+str(sku),"name":str(Model.SKU_NAMES[sku])+" restock practice","description":"25% more restock speed per tier for this product; applies to the next shift."})
	improvements.append({"key":"checkout","name":"A smoother checkout","description":"25% more checkout speed per tier; applies to the next shift."})
	for upgrade in improvements:
		var card := _vbox(_panel(box,Color("f0e2c7")))
		var tier := int(profile.data.upgrades[upgrade.key])
		_text(card,"%s  ·  %d/3" % [upgrade.name,tier],30)
		_text(card,upgrade.description,24)
		var cost := profile.upgrade_cost(upgrade.key)
		var button := _button(card,"Fully improved" if tier >= 3 else "Improve · %d coins" % cost,func():
			var bought: bool = profile.buy_upgrade(upgrade.key)
			if bought:
				_sfx("confirm")
			show_growth()
			if not bought: _notice("The improvement could not save. Your coins were kept."))
		button.disabled = tier >= 3 or int(profile.data.coins) < cost

func show_daily() -> void:
	profile.roll_day(Profile.today())
	var box := _menu("Daily baskets","A fresh welcome each UTC day. Nothing is lost if you miss a day.")
	_text(box,"Today's corner · "+str(profile.data.daily.day),30,TEAL)
	var today_id := profile.daily_shift(Profile.today())
	_button(box,"Play today's basket · Shift %d" % today_id,func(): _confirm_start(today_id,false,true))
	_text(box,"Daily basket complete" if profile.data.daily.won else "Complete today's basket to add a daily welcome.",23)
	_text(box,"Seven-day welcome calendar",31)
	var calendar := _row(box,6)
	var filled := int(profile.data.login_claims)%7
	if filled == 0 and int(profile.data.login_claims) > 0: filled = 7
	for index in range(7):
		var card := _vbox(_panel(calendar,Color("d1e1ca") if index < filled else Color("f0e2c7")),3)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_text(card,"%d" % (index+1),24)
		_text(card,"%d" % (12+index*4),21)
	var login := _button(box,"Collect today's welcome",func():
		var amount: int = profile.claim_login(Profile.today())
		_check_badges()
		show_daily()
		_notice("Welcome back · +%d coins" % amount if amount > 0 else "The welcome could not save. Please check free device space."))
	login.disabled = Profile.today() <= str(profile.data.login_day)
	for goal in profile.daily_goals():
		var card := _vbox(_panel(box,Color("f0e2c7")))
		var current := int(profile.data.daily.get(goal.key,0))
		_text(card,"%s · %d/%d" % [goal.name,mini(current,int(goal.target)),int(goal.target)],27)
		var claimed: bool = goal.key in profile.data.daily.claims
		var button := _button(card,"Collected" if claimed else "Collect · %d coins" % int(goal.reward),func():
			var amount: int = profile.claim_daily(goal.key)
			_check_badges()
			show_daily()
			_notice("Daily goal · +%d coins" % amount if amount > 0 else "This goal could not save. Your claim was kept."))
		button.disabled = claimed or current < int(goal.target)
	profile.save()

func show_journal() -> void:
	var box := _menu("Our regulars","Six familiar faces, each with a little story. Serve them to fill your journal.")
	for regular in catalog.regulars:
		var card := _vbox(_panel(box,Color("f0e2c7")))
		var met: bool = profile.data.regulars.has(regular.name)
		_text(card,regular.name+(" · A familiar face" if met else " · Say hello in the shop"),31,TEAL)
		_text(card,regular.line,25)
		_text(card,"Favorite: "+str(catalog.products[regular.favorite].name),22)

func _badge_image(parent: Node, path: String) -> void:
	if not ResourceLoader.exists("res://"+path): return
	var image := TextureRect.new()
	image.texture = load("res://"+path)
	image.custom_minimum_size = Vector2(100,100)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(image)

func _picture(parent: Node, path: String, extent: int) -> TextureRect:
	var image := TextureRect.new()
	if ResourceLoader.exists(path): image.texture = load(path)
	image.custom_minimum_size = Vector2(extent,extent)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _product_icon_path(sku: String) -> String:
	var illustrated := "res://assets/art/products/%s.png" % sku
	return illustrated if ResourceLoader.exists(illustrated) else "res://assets/ui/products/%s.png" % sku

func _ignore_child_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_child_mouse(child)

func show_achievements() -> void:
	_check_badges()
	var box := _menu("Badges & records","Your neighborhood story stays local. Play Games is optional.")
	for badge in catalog.achievements:
		var row := _row(_panel(box,Color("dce6d2") if badge.key in profile.data.unlocks else Color("f0e2c7")))
		_badge_image(row,badge.icon)
		var text := _vbox(row,4)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_text(text,badge.name,29,TEAL)
		_text(text,badge.description,23)
		_text(text,"Earned" if badge.key in profile.data.unlocks else "%d/%d" % [mini(profile.metric(badge.metric),int(badge.target)),int(badge.target)],22)
	_text(box,"Neighborhood records",33,TEAL)
	for board in catalog.leaderboards:
		var row := _row(_panel(box,Color("f0e2c7")))
		_badge_image(row,board.icon)
		var text := _vbox(row,5)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_text(text,board.name+" · %d" % profile.metric(board.metric),28)
		_text(text,board.description,22)
		if services != null: _button(text,"Open Play Games record",func(): services.open_leaderboards(board.key),Color("6e8787"))
	if services != null: _button(box,"Play Games achievements",func(): services.open_achievements())

func show_settings() -> void:
	var box := _menu("A comfortable corner","Choose how your shop sounds. Local play is always available.")
	_button(box,"Music: "+("On" if profile.data.music else "Off"),func():
		profile.data.music = not bool(profile.data.music)
		_audio_settings()
		profile.save()
		show_settings())
	_button(box,"Sound effects: "+("On" if profile.data.effects else "Off"),func():
		profile.data.effects = not bool(profile.data.effects)
		_audio_settings()
		profile.save()
		show_settings())
	if services != null:
		_text(box,str(services.status()),23)
		_button(box,"Sign in to Play Games",func(): services.sign_in())
		_button(box,"Privacy options",func(): services.privacy_options(),Color("6e8787"))
	_text(box,"How to play",32,TEAL)
	_text(box,"Customers collect their requested items from your shelves. Tap a shelf or its large card to restock it. When a basket is complete, tap the customer's Checkout card. Go to checkout sends the clerk to wait for one complete basket, even before it arrives. One job can run while one waits; tap Cancel queued job to change your plan. Incomplete baskets never pay.",26)
	_text(box,"Ordinary retries and untimed practice are free. Ordinary courier delivery is free: call when a product reserve is empty, wait 20-45 seconds of active play, then tap Meet courier so your clerk collects the parcel at the front door. Optional extra ad reserve needs a real earned ad; unavailable or closed ads never grant anything. Assisted combos stay out of the unassisted record.",24)
	_text(box,"Made with Godot and selected Kenney CC0 art. Original game work Apache 2.0. License notices accompany the package.",21)

func _confirm_start(id: int, practice: bool=false, daily: bool=false) -> void:
	if not profile.data.active.is_empty():
		var box := _modal("A shift is already saved","Resume it from Home, or start fresh. Sales from an unfinished shift are not banked.")
		_button(box,"Keep my saved shift",_close_modal)
		_button(box,"Start this shift fresh",func():
			profile.data.active = {}
			_start_shift(id,practice,daily),CORAL)
	else:
		_start_shift(id,practice,daily)

func _start_shift(id: int, practice: bool=false, daily: bool=false) -> void:
	model = Model.new()
	model.new_shift(id,practice,profile.data.upgrades)
	daily_mode = daily
	daily_day = Profile.today() if daily else ""
	paused = false
	result_banked = false
	settle_error = false
	_build_game()
	_save_active()
	if not bool(profile.data.tutorial_seen):
		paused = true
		var box := _modal("Welcome to your corner","Customers collect the items shown in their basket. Restock a low shelf, then check out each COMPLETE basket. The clerk can hold one extra job in the queue. All shop time waits while this card is open.")
		_button(box,"Raise the awning",func():
			profile.data.tutorial_seen = true
			paused = false
			_close_modal()
			_save_active())
	_sfx("door")

func _resume_saved() -> void:
	model = Model.new()
	if not model.restore(profile.data.active.get("model",{})):
		_notice("Your saved shift could not be read. It has been kept for recovery.")
		model = null
		return
	daily_mode = bool(profile.data.active.get("daily",false))
	daily_day = str(profile.data.active.get("daily_day",""))
	result_banked = false
	_build_game()
	_pause_shift("Your shop is ready","Your stock, baskets and task queue were restored. Resume when you are ready.")

func _build_game() -> void:
	_close_modal()
	_page("game","%02d · %s" % [int(model.state.shift_id),model.definition.title])
	world.show_shift(model.skus(),int(model.definition.chapter)-1)
	world.sync(model.state,0)
	var hud := _vbox(_panel(page,Color("fff2daef")),4)
	shift_label = _text(hud,"",27)
	shift_progress = ProgressBar.new()
	shift_progress.custom_minimum_size.y = 13
	shift_progress.show_percentage = false
	hud.add_child(shift_progress)
	_spacer(page)
	var controls := _vbox(_panel(page,Color("fff2daf5")),8)
	_text(controls,"SHELVES  ·  Tap to restock from reserve",21,TEAL)
	var grid := GridContainer.new()
	grid.columns = 3 if model.skus().size() > 2 else 2
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	controls.add_child(grid)
	for sku in model.skus():
		var key := str(sku)
		var button := _button(grid,"",func(): _queue_task("restock",key),Color(catalog.products[key].color).darkened(0.28))
		button.custom_minimum_size.y = 128
		button.add_theme_font_size_override("font_size",21)
		var icon_path := _product_icon_path(key)
		if ResourceLoader.exists(icon_path): button.icon = load(icon_path)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",58)
		stock_buttons[key] = button
	basket_label = _text(controls,"BASKETS  ·  Checkout only when complete",21,TEAL)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 238
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	controls.add_child(scroll)
	customer_row = _row(scroll,8)
	task_label = _text(controls,"",22)
	task_progress = ProgressBar.new()
	task_progress.show_percentage = false
	task_progress.custom_minimum_size.y = 12
	controls.add_child(task_progress)
	var delivery_row := _row(controls,8)
	# This camera sees the actual courier/parcel in the existing world, not a
	# second actor or simulated delivery. Only render the tiny inset while waiting.
	courier_preview = SubViewportContainer.new()
	courier_preview.custom_minimum_size = Vector2(160,128)
	courier_preview.stretch = true
	courier_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	delivery_row.add_child(courier_preview)
	courier_viewport = SubViewport.new()
	courier_viewport.size = Vector2i(160,128)
	courier_viewport.world_3d = viewport.find_world_3d()
	courier_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	courier_preview.add_child(courier_viewport)
	courier_camera = Camera3D.new()
	courier_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	courier_camera.size = 3.1
	courier_viewport.add_child(courier_camera)
	courier_camera.position = Vector3(6.6,3.2,8)
	courier_camera.look_at(Vector3(3.2,.95,3.6))
	courier_camera.current = true
	courier_status = _text(delivery_row,"",22,TEAL)
	courier_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	courier_button = _button(delivery_row,"Call for delivery",_courier_action,CORAL)
	courier_button.name = "CourierAction"
	courier_button.custom_minimum_size = Vector2(300,128)
	var row := _row(controls,8)
	checkout_button = _button(row,"Go to checkout",func(): _queue_task("checkout",-1),TEAL)
	checkout_button.name = "GoCheckout"
	checkout_button.custom_minimum_size.y = 128
	_button(row,"Pause",func(): _pause_shift("A little breather","Everything in the shop waits for you."),Color("6e8787"))
	_button(row,"Cancel queued job",func():
		if model != null: model.cancel_queued(),Color("6e8787"))
	var aid := _button(row,"Ad reserve +3",_request_reserve,CORAL)
	aid.visible = not bool(model.state.practice) and int(model.state.shift_id) > 1
	_refresh_game()
	_music(str(catalog.themes[int(model.definition.chapter)-1].music))

func _order_text(customer: Dictionary) -> String:
	var lines: Array[String] = []
	for sku in customer.order:
		lines.append("%s %d/%d" % [catalog.products[sku].name,int(customer.basket.get(sku,0)),int(customer.order[sku])])
	return ", ".join(lines)

func _refresh_game() -> void:
	if model == null or not is_instance_valid(shift_label): return
	var state: Dictionary = model.state
	checkout_button.disabled = paused
	var courier: Dictionary = state.courier
	courier_button.visible = model.ruleset == Model.CURRENT_RULESET
	courier_status.visible = courier_button.visible
	courier_preview.visible = courier_button.visible and courier.phase == "waiting"
	courier_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if courier_preview.visible else SubViewport.UPDATE_DISABLED
	courier_button.text = "Meet courier at door" if courier.phase == "waiting" else "Courier on the way" if courier.phase == "transit" else "Call for delivery"
	courier_button.disabled = paused or (not model.can_call_delivery() and courier.phase != "waiting")
	courier_status.text = "Arrives in %ds of play" % int(ceil(float(courier.remaining))) if courier.phase == "transit" else "At front door - collect parcel" if courier.phase == "waiting" else "Call when a product reserve is empty"
	courier_button.tooltip_text = "Free ordinary supply. Courier takes 20-45 seconds of active play; the clerk must collect at the front door."
	shift_label.text = "%s  ·  %d/%d neighbors  ·  %d coins" % ["Practice" if state.practice else "%ds" % int(ceil(float(state.remaining))),int(state.served),int(model.definition.target),int(state.revenue)]
	shift_progress.max_value = float(model.definition.duration)
	shift_progress.value = float(state.remaining)
	var ready_count := 0
	var shopping_count := 0
	for visitor in state.customers:
		if visitor.phase == "ready": ready_count += 1
		elif visitor.phase in ["shopping","to_checkout"]: shopping_count += 1
	basket_label.text = "BASKETS  ·  %d ready / %d shopping  ·  Swipe to see all" % [ready_count,shopping_count]
	for sku in stock_buttons:
		stock_buttons[sku].text = "%s  %d/%d\nReserve %d\nRESTOCK" % [catalog.products[sku].name,int(state.shelves[sku]),int(state.capacities[sku]),int(state.reserve[sku])]
		stock_buttons[sku].disabled = paused or int(state.reserve[sku]) <= 0 or int(state.shelves[sku]) >= int(state.capacities[sku])
	for customer in state.customers:
		var id := int(customer.id)
		if not customer_buttons.has(id):
			# The whole card is one large action. Children never consume a tap and
			# there is no nested second handler that could duplicate checkout.
			var button := _button(customer_row,"",func(): _queue_task("checkout",id),Color("e1ead6"))
			button.custom_minimum_size = Vector2(300,214)
			var card := _vbox(button,4)
			card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			card.offset_left = 10
			card.offset_right = -10
			card.offset_top = 8
			card.offset_bottom = -8
			var row := _row(card,7)
			var regular: Dictionary = catalog.regulars[int(customer.get("regular",id%6))]
			_picture(row,"res://assets/ui/regulars/%s.png" % regular.model,36)
			var name_label := _text(row,"",21,TEAL)
			name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var order := _vbox(card,3)
			var amounts: Dictionary = {}
			var product_names: Dictionary = {}
			var product_rows: Dictionary = {}
			for sku in customer.order:
				var item := _row(order,6)
				_picture(item,_product_icon_path(str(sku)),28)
				var product_name := _text(item,str(catalog.products[sku].name),19)
				product_name.autowrap_mode = TextServer.AUTOWRAP_OFF
				product_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var amount := _text(item,"",19)
				amount.autowrap_mode = TextServer.AUTOWRAP_OFF
				amount.custom_minimum_size.x = 48
				amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				amounts[sku] = amount
				product_names[sku] = product_name
				product_rows[sku] = item
			var patience := ProgressBar.new()
			patience.show_percentage = false
			patience.custom_minimum_size.y = 6
			card.add_child(patience)
			var action_panel := _panel(card,TEAL)
			action_panel.custom_minimum_size.y = 44
			var action_text := _text(action_panel,"",22,Color("fff9ea"))
			action_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			action_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			customer_buttons[id] = button
			customer_cards[id] = {"panel":button,"name":name_label,"amounts":amounts,"product_names":product_names,"product_rows":product_rows,"patience":patience,"action_panel":action_panel,"action_text":action_text}
			_ignore_child_mouse(button)
		var button: Button = customer_buttons[id]
		var card: Dictionary = customer_cards[id]
		card.panel.visible = customer.phase not in ["served","lost"]
		var status := "COMPLETE" if customer.phase == "ready" else "To checkout" if customer.phase == "to_checkout" else "Shopping"
		var instruction := "Checkout" if customer.phase == "ready" else "Walking to counter" if customer.phase == "to_checkout" else "Collecting"
		card.name.text = "%s · %s" % [customer.name,status]
		for sku in card.amounts:
			card.amounts[sku].text = "%d/%d" % [int(customer.basket.get(sku,0)),int(customer.order[sku])]
		card.patience.max_value = float(customer.max_patience)
		card.patience.value = float(customer.patience)
		card.action_text.text = "%s · %ds" % [instruction,int(ceil(float(customer.patience)))]
		var action_style := _style(CORAL if float(customer.patience) < 15 else TEAL if customer.phase == "ready" else Color("758a86"),12)
		action_style.content_margin_left = 8
		action_style.content_margin_right = 8
		action_style.content_margin_top = 6
		action_style.content_margin_bottom = 6
		card.action_panel.add_theme_stylebox_override("panel",action_style)
		button.disabled = paused or customer.phase != "ready"
	var task: Dictionary = state.active_task
	var queued: Dictionary = state.queued_task
	task_label.text = str(state.last_action)+( "  ·  Next: "+_task_name(queued) if not queued.is_empty() else "  ·  Queue empty")
	task_progress.max_value = float(task.get("duration",1))
	task_progress.value = float(task.get("duration",1))-float(task.get("remaining",1))

func _task_name(task: Dictionary) -> String:
	if task.is_empty(): return "None"
	if task.kind == "collect_delivery": return "Meet courier at front door"
	return "Restock "+str(catalog.products[str(task.target)].name) if task.kind == "restock" else "Go to checkout" if int(task.target) == -1 else "Checkout basket"

func _courier_action() -> void:
	if model == null: return
	_queue_task("collect_delivery" if model.state.courier.phase == "waiting" else "call_delivery","front_door")

func _queue_task(kind: String, target: Variant) -> void:
	if screen != "game" or paused or background or reward_pending or ad_waiting or model == null: return
	if model.queue_task(kind,target):
		_sfx("click")
		_save_active()
	else:
		_notice(str(model.last_error))
	_refresh_game()

func _process(delta: float) -> void:
	if world == null: return
	var fullscreen: bool = services != null and services.fullscreen_ad_active()
	if fullscreen:
		ad_waiting = true
		paused = true
	if ad_waiting and not fullscreen and not reward_pending:
		ad_waiting = false
		if model != null and screen == "game":
			_pause_shift("Welcome back","Your shop waited through the whole message. Resume when you are ready.")
	var freeze := paused or background or reward_pending or fullscreen or ad_waiting
	var pause_music: bool = background or fullscreen or reward_pending
	# Web samples restart their buffer on redundant unpause calls.
	if music.stream_paused != pause_music:
		music.stream_paused = pause_music
	if model == null:
		world.set_frozen(background or fullscreen or reward_pending)
		return
	model.set_paused(freeze)
	world.set_frozen(freeze)
	if screen == "game":
		model.step(delta)
		world.sync(model.state,0 if freeze else minf(delta,0.1))
		sound_clock += delta
		if not freeze and str(model.state.get("clerk_motion","idle")) == "walk" and sound_clock > 0.5:
			sound_clock = 0
			_sfx("footstep")
		for event in model.drain_events():
			if event.kind == "checkout": _sfx("coin")
			elif event.kind == "restocked": _sfx("restock")
			elif event.kind == "arrival": _sfx("door")
			elif event.kind == "customer_lost": _sfx("error")
			elif event.kind == "delivery": _notice("A fresh reserve delivery has arrived.")
			elif event.kind == "courier_arrived":
				_sfx("door")
				_notice("Courier at the front door. Tap Meet courier to collect your parcel.")
			elif event.kind == "courier_collected": _sfx("restock")
		if model.state.status != "active" and not result_banked and not settle_error:
			_settle_shift()
		refresh_clock += delta
		auto_save += delta
		if refresh_clock >= 0.2:
			refresh_clock = 0
			_refresh_game()
		if auto_save >= 5 and model.state.status == "active":
			auto_save = 0
			_save_active()

func _settle_shift() -> void:
	paused = true
	var transaction: Dictionary = profile.settle_model(model,daily_mode,daily_day)
	var receipt: Dictionary = transaction.receipt
	if not bool(transaction.ok):
		settle_error = true
		var box := _modal("Your earnings are waiting","Your shift is complete, but the save could not be written. Your rewards have not been claimed twice. Please free some device space and retry saving.")
		_button(box,"Retry saving",func():
			settle_error = false
			_close_modal()
			_settle_shift())
		return
	result_banked = true
	_check_badges()
	_show_result(receipt)
	if services != null and bool(receipt.won) and not bool(receipt.practice) and bool(receipt.get("claimed",false)):
		services.round_finished()

func _show_result(receipt: Dictionary) -> void:
	_close_modal()
	var title := "A lovely shift" if receipt.won else "Tomorrow is another day"
	var box := _modal(title,"%d neighbors served · %d restocks · %ds" % [int(receipt.served),int(receipt.restocks),int(receipt.elapsed)])
	_stars(box,int(receipt.stars))
	_text(box,"Practice · no coins or XP banked" if receipt.practice else "+%d coins  ·  +%d manager XP\nSafely saved, once." % [int(receipt.coins),int(receipt.xp)],30,TEAL)
	if int(receipt.get("level_bonus",0)) > 0:
		var gifts: Array[String] = []
		for gift in receipt.get("level_rewards",[]): gifts.append("Level %d: +%d coins" % [int(gift.level),int(gift.coins)])
		_text(box,"Manager welcome gift · "+", ".join(gifts),24,CORAL)
		_text(box,"Total above includes %d shift coins and %d level-up coins." % [int(receipt.get("base_coins",0)),int(receipt.level_bonus)],22)
	if not receipt.won: _text(box,"Target: %d neighbors. Ordinary retries and practice are always free." % int(model.definition.target),24)
	if receipt.assisted: _text(box,"Assisted shift · combo excluded from the unassisted record.",22)
	_button(box,"Back to the neighborhood",show_home)
	_button(box,"Replay this shift",func(): _start_shift(int(receipt.shift_id),bool(receipt.practice),daily_mode))
	if receipt.won and int(receipt.shift_id) < 36 and not daily_mode:
		_button(box,"Next shift",func(): _start_shift(int(receipt.shift_id)+1))
	_sfx("confirm")

func _check_badges() -> void:
	for key in profile.check_achievements(catalog):
		if services != null: services.unlock(key)
	if services != null:
		for board in catalog.leaderboards: services.submit(board.key,profile.metric(board.metric))
	profile.save()
	_refresh_header()

func _save_active(show_error: bool=true) -> bool:
	if model == null or model.state.is_empty() or result_banked: return true
	profile.data.active = {"model":model.snapshot(),"daily":daily_mode,"daily_day":daily_day}
	var saved: bool = profile.save()
	if not saved and show_error: _notice("The shop could not save. Please check free device space.")
	return saved

func _pause_shift(title: String, message: String, defer_ui: bool=false) -> void:
	if model == null or model.state.status != "active": return
	paused = true
	model.set_paused(true)
	world.set_frozen(true)
	# Application notifications propagate with Node's child list locked. Freeze
	# and persist now, but create controls only after propagation has returned.
	var saved: bool = _save_active(not defer_ui)
	if not defer_ui:
		pending_pause_ui.clear()
		_show_pause_controls(title,message)
		return
	var run_id := str(model.state.run_id)
	if not pending_pause_ui.is_empty() and pending_pause_ui.model == model and pending_pause_ui.run_id == run_id:
		pending_pause_ui.save_failed = bool(pending_pause_ui.save_failed) or not saved
		return
	pause_ui_generation += 1
	pending_pause_ui = {"token":pause_ui_generation,"model":model,"run_id":run_id,"title":title,"message":message,"save_failed":not saved}
	_flush_pause_controls.call_deferred(pause_ui_generation)

func _flush_pause_controls(token: int) -> void:
	if pending_pause_ui.is_empty() or int(pending_pause_ui.token) != token: return
	var request: Dictionary = pending_pause_ui
	pending_pause_ui = {}
	if not is_inside_tree() or is_queued_for_deletion() or screen != "game": return
	if model == null or model != request.model or str(model.state.get("run_id","")) != str(request.run_id) or model.state.get("status","") != "active": return
	if reward_pending or ad_waiting or (services != null and services.fullscreen_ad_active()): return
	_show_pause_controls(str(request.title),str(request.message))
	if bool(request.save_failed): _notice("The shop could not save. Please check free device space.")

func _show_pause_controls(title: String, message: String) -> void:
	var paused_model: Model = model
	var paused_run := str(model.state.run_id)
	var box := _modal(title,message)
	_button(box,"Resume the shop",func():
		if background or reward_pending or ad_waiting or (services != null and services.fullscreen_ad_active()): return
		if screen != "game" or model != paused_model or str(model.state.run_id) != paused_run: return
		paused = false
		_close_modal())
	_button(box,"Save & Home",func():
		_save_active()
		show_home(),Color("6e8787"))

func _request_reserve() -> void:
	if model == null or paused or int(model.state.shift_id) <= 1 or bool(model.state.reward_used):
		_notice("A reserve delivery is available once per ordinary shift after the first.")
		return
	paused = true
	var box := _modal("A little extra stock","An optional earned message brings +3 reserve items per product. Your shop waits until the whole message closes. Ordinary play and retries remain free.")
	_button(box,"Keep playing",func():
		paused = false
		_close_modal())
	var available: bool = services != null and services.can_reward()
	var button := _button(box,"Request earned reserve" if available else "No earned message available",func():
		if services == null: return
		reward_pending = true
		ad_waiting = true
		paused = true
		reward_token = str(model.state.run_id)+"-reserve"
		var token := reward_token
		_close_modal()
		_save_active()
		services.reward_requested(token,func(earned: bool):
			if token != reward_token: return
			reward_pending = false
			if model != null and str(model.state.run_id)+"-reserve" == token:
				if earned:
					model.apply_earned_assistance("reserve")
					_save_active()
				else:
					_notice("No reserve was granted. Your ordinary shift is unchanged.")))
	button.disabled = not available

func _modal(title: String, message: String) -> VBoxContainer:
	_close_modal()
	modal = ColorRect.new()
	modal.color = Color(0.08,0.16,0.19,0.72)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",55)
	margin.add_theme_constant_override("margin_right",55)
	margin.add_theme_constant_override("margin_top",100)
	margin.add_theme_constant_override("margin_bottom",100)
	modal.add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var panel := _panel(center)
	panel.custom_minimum_size.x = maxf(300,size.x-140)
	var box := _vbox(panel,18)
	_text(box,title,38,TEAL)
	_text(box,message,27)
	return box

func _close_modal() -> void:
	if is_instance_valid(modal):
		modal.hide()
		modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		modal.process_mode = Node.PROCESS_MODE_DISABLED
		modal.queue_free()
	modal = null

func _notice(message: String) -> void:
	if message.is_empty(): return
	if is_instance_valid(footer):
		footer.text = message
	else:
		# Nonblocking toast; do not replace an active ad/resume/result modal.
		var context: Control = header.get_parent().get_parent() if is_instance_valid(header) else null
		if screen == "game" and is_instance_valid(shift_label) and shift_label.is_inside_tree():
			context = shift_label.get_parent().get_parent()
		var notice_top := 24.0
		if is_instance_valid(context):
			var context_end: Vector2 = get_global_transform().affine_inverse()*context.get_global_rect().end
			notice_top = context_end.y+12
		var toast := _panel(self,CREAM)
		toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		toast.offset_left = 32
		toast.offset_right = -32
		toast.offset_top = notice_top
		toast.offset_bottom = notice_top+100
		toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var text := _text(toast,message,25,INK)
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_tree().create_timer(3).timeout.connect(func():
			if is_instance_valid(toast): toast.queue_free())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if screen == "game" and modal == null and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if world.select_at(event.position): accept_event()

func _back() -> void:
	if screen == "game":
		if model != null and model.state.status == "active": _pause_shift("A little breather","Everything in the shop waits for you.")
		else: show_home()
	elif screen != "home": show_home()
	else:
		var box := _modal("Close the shop?","Your neighborhood progress is safely saved.")
		_button(box,"Stay a little longer",_close_modal)
		_button(box,"Save & close",_quit,Color("6e8787"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		background = true
		if model != null and screen == "game" and not reward_pending and not ad_waiting:
			_pause_shift("Your shop waited","Resume when you are ready.",true)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		background = false
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()
	elif what == NOTIFICATION_EXIT_TREE:
		pending_pause_ui.clear()

func _quit() -> void:
	_save_active()
	if profile != null: profile.save()
	_shutdown_audio()
	get_tree().quit()

func _shutdown_audio() -> void:
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	for player in effects:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func _exit_tree() -> void:
	_shutdown_audio()
