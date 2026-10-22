extends Node3D
## View only: stock, basket payment and all simulation time belong to MarketModel.
signal target_selected(kind: String, target: Variant)
const MARKET := "res://assets/kenney/market/"
const PEOPLE := "res://assets/kenney/characters/"
var catalog: Dictionary = {}
var cache: Dictionary = {}
var shelves: Dictionary = {}
var products: Dictionary = {}
var labels: Dictionary = {}
var markers: Dictionary = {}
var actors: Dictionary = {}
var actor_labels: Dictionary = {}
var positions := [Vector3(-2.35,0.04,-1.35),Vector3(-0.15,0.04,-1.35),Vector3(2.05,0.04,-1.35),Vector3(-2.35,0.04,0.7),Vector3(-0.15,0.04,0.7),Vector3(2.05,0.04,0.7)]
var current_skus: Array = []
var state: Dictionary = {}
var camera: Camera3D
var clerk: Node3D
var environment: Environment
var sun: DirectionalLight3D
var lights: Array = []
var frozen := false
var clerk_home := Vector3(0,0.04,1.35)
var decorations: Array = []
var rain_emitters: Array = []
var home_mode := false
var neighbors: Array = []
var neighborhood_time := 0.0
var theme_decor: Array = []
var shop_sign: Label3D
var shop_subtitle: Label3D

func setup(data: Dictionary) -> void:
	catalog = data
	var world_env := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = environment
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-32,0)
	sun.light_color = Color("fff0ce")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 11.0
	camera.v_offset = -1.25
	camera.position = Vector3(9,12,13)
	add_child(camera)
	camera.look_at(Vector3(0,0,-0.45))
	camera.current = true
	box(Vector3(20,0.35,17),Vector3(0,-0.3,1),Color("88ad9b"))
	box(Vector3(12,0.15,2.2),Vector3(0,-0.06,4),Color("c1b9a7"))
	box(Vector3(19,0.12,2.6),Vector3(0,-0.16,6.5),Color("657c80"))
	for x in range(-7,8,3):
		box(Vector3(1.4,0.015,0.1),Vector3(x,-0.08,6.5),Color("f8e8af"))
	for x in range(-3,4):
		for z in range(-3,3):
			asset(MARKET+"floor.glb",Vector3(x,0,z))
	for x in range(-3,4):
		asset(MARKET+("wall-window.glb" if x%2==0 else "wall.glb"),Vector3(x,0,-3.5))
	for z in range(-3,2):
		asset(MARKET+("wall-window.glb" if z%2==0 else "wall.glb"),Vector3(-3.5,0,z),1,PI/2)
	box(Vector3(7.7,0.18,0.18),Vector3(0,0.1,2.7),Color("e8cbb0"))
	box(Vector3(0.16,0.22,6.2),Vector3(3.6,0.1,-0.4),Color("e8cbb0"))
	for x in [-3.4,3.4]:
		asset(MARKET+"column.glb",Vector3(x,0,-3.4),1.3)
		asset("res://assets/kenney/furniture/pottedPlant.glb",Vector3(x,0,2.6),1.4)
	asset(MARKET+"cash-register.glb",Vector3(0,0.03,2),1.2)
	asset(MARKET+"shopping-basket.glb",Vector3(2.9,0.03,2.25),0.9)
	asset(MARKET+"shopping-cart.glb",Vector3(3.7,0.02,3.6),0.9,-0.45)
	asset(MARKET+"wall-door-rotate.glb",Vector3(3,0,-3.5))
	asset("res://assets/kenney/commercial/detail-awning-wide.glb",Vector3(0,2.25,-3.5),1.7)
	shop_sign = label("CORNER MARKET",Vector3(0,2.65,-3.5),57)
	shop_subtitle = label("Fresh things. Familiar faces.",Vector3(0,2.2,-3.45),27)
	for index in range(4):
		asset("res://assets/kenney/furniture/cardboardBoxClosed.glb",Vector3(-3.1+(index%2)*0.32,(index/2)*0.24,-2.6),1.4)
	asset("res://assets/kenney/furniture/cardboardBoxOpen.glb",Vector3(-2.5,0.05,-2.7),1.6)
	for x in [-5.3,5.2]:
		asset("res://assets/kenney/nature/tree_small.glb",Vector3(x,-0.1,1.8),1.9)
		asset("res://assets/kenney/furniture/bench.glb",Vector3(x-0.5,0,3.7),1.1)
		asset("res://assets/kenney/nature/plant_bush.glb",Vector3(x,0,-2),1.6)
		asset("res://assets/kenney/nature/flower_yellowA.glb",Vector3(x+0.5,0,2.5),1.6)
	asset("res://assets/kenney/commercial/building-a.glb",Vector3(-7,0,-6.5),1.3)
	asset("res://assets/kenney/commercial/low-detail-building-b.glb",Vector3(6.3,0,-6.8),1.8)
	for x in [-2.9,2.9]:
		asset("res://assets/kenney/furniture/lampWall.glb",Vector3(x,1.55,-3.2),1.5)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x,1.7,-2.6)
		lamp.omni_range = 4
		lamp.light_color = Color("ffd58d")
		add_child(lamp)
		lights.append(lamp)
	for index in range(3):
		var decor := asset("res://assets/kenney/nature/flower_yellowA.glb",Vector3(-2.3+index*2.1,0.05,3.6),2.0)
		decor.visible = false
		decorations.append(decor)
	for x in [-5.0,5.0]:
		var drops := CPUParticles3D.new()
		drops.amount = 55
		drops.lifetime = 1.3
		drops.position = Vector3(x,3,0)
		drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		drops.emission_box_extents = Vector3(1.2,1.0,3.0)
		drops.direction = Vector3(0,-1,0)
		drops.spread = 4
		drops.initial_velocity_min = 5
		drops.initial_velocity_max = 7
		drops.gravity = Vector3.ZERO
		var drop_mesh := BoxMesh.new()
		drop_mesh.size = Vector3(0.015,0.2,0.015)
		var drop_material := StandardMaterial3D.new()
		drop_material.albedo_color = Color("b4d5df")
		drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		drop_mesh.material = drop_material
		drops.mesh = drop_mesh
		add_child(drops)
		rain_emitters.append(drops)
	for index in range(6):
		var group := Node3D.new()
		add_child(group)
		theme_decor.append(group)
	for x in [-4.4,4.3]:
		theme_asset(1,MARKET+"display-bread.glb",Vector3(x,0.02,3.3),1.4)
		theme_asset(3,MARKET+"display-fruit.glb",Vector3(x,0.02,3.3),1.5)
		theme_asset(2,"res://assets/kenney/furniture/pottedPlant.glb",Vector3(x,0.02,2.8),1.6)
		theme_asset(4,"res://assets/kenney/furniture/bench.glb",Vector3(x,0.02,3.3),1.4)
		theme_asset(5,"res://assets/kenney/furniture/lampWall.glb",Vector3(x,1.7,2.8),1.6)
	var tram := label("TRAM STOP\nNext stop: a little kindness.",Vector3(4.5,1.6,3.0),31)
	remove_child(tram)
	theme_decor[4].add_child(tram)
	var bakery := label("FRESH FROM\nTHE OVEN",Vector3(-4.5,1.25,3.25),30)
	remove_child(bakery)
	theme_decor[1].add_child(bakery)
	var market_day := label("MARKET DAY",Vector3(4.4,1.25,3.3),32)
	remove_child(market_day)
	theme_decor[3].add_child(market_day)
	for index in range(7):
		var lantern := box(Vector3(0.15,0.2,0.15),Vector3(-3+index,2.2,2.7),Color("f3c878"))
		remove_child(lantern)
		theme_decor[5].add_child(lantern)
	for index in range(catalog.sku_order.size()):
		var sku: String = catalog.sku_order[index]
		var product: Dictionary = catalog.products[sku]
		var node := asset(MARKET+product.model+".glb",positions[index],1.35)
		shelves[sku] = node
		products[sku] = product_children(node)
		labels[sku] = label(product.name,positions[index]+Vector3(0,1.15,0),30)
		markers[sku] = []
		for marker in range(7):
			markers[sku].append(box(Vector3(0.13,0.065,0.1),positions[index]+Vector3(-0.45+marker*0.15,0.08,0.6),Color(product.color)))
	clerk = asset(MARKET+"character-employee.glb",clerk_home,1.25)
	animate(clerk,"idle")
	set_theme(0)

func box(size_value: Vector3, position_value: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	node.material_override = material
	node.position = position_value
	add_child(node)
	return node

func asset(path: String, position_value: Vector3, factor: float=1, rotation_value: float=0) -> Node3D:
	if not cache.has(path):
		cache[path] = load(path)
	var wrapper := Node3D.new()
	add_child(wrapper)
	wrapper.position = position_value
	wrapper.scale = Vector3.ONE*factor
	wrapper.rotation.y = rotation_value
	if cache[path] is PackedScene:
		wrapper.add_child(cache[path].instantiate())
	else:
		push_error("Required shop model failed to import: "+path)
	return wrapper

func theme_asset(index: int, path: String, position_value: Vector3, factor: float) -> void:
	var node := asset(path,position_value,factor)
	remove_child(node)
	theme_decor[index].add_child(node)

func label(value: String, position_value: Vector3, font_size: int) -> Label3D:
	var node := Label3D.new()
	node.text = value
	node.position = position_value
	node.font_size = font_size
	node.pixel_size = 0.006
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.no_depth_test = true
	node.modulate = Color("fff4df")
	node.outline_modulate = Color("203d46")
	node.outline_size = 10
	add_child(node)
	return node

func product_children(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		var lower := str(child.name).to_lower()
		if child is Node3D and (lower.begins_with("produce_") or lower.begins_with("bag") or lower.begins_with("bread") or lower.begins_with("carton") or lower.begins_with("box") or lower.begins_with("bottle")):
			result.append(child)
		else:
			result.append_array(product_children(child))
	return result

func animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := animation_player(child)
		if found != null:
			return found
	return null

func animate(node: Node, desired: String) -> void:
	var player := animation_player(node)
	if player == null:
		return
	# An interaction clip is a single action; repeated sync must not restart it.
	if str(node.get_meta("animation_goal","")) == desired:
		return
	for animation_name in player.get_animation_list():
		if str(animation_name).split("/")[-1] == desired:
			node.set_meta("animation_goal",desired)
			player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR if desired in ["idle","walk","holding-both"] else Animation.LOOP_NONE
			player.play(animation_name,0.16)
			return

func set_theme(index: int) -> void:
	var night := index == 5
	var rainy := index == 2
	var sky_colors := [Color("a3c6c8"),Color("e2b98f"),Color("a3bac7"),Color("c2ca9b"),Color("9fbbc7"),Color("343f67")]
	environment.background_color = sky_colors[clampi(index,0,5)]
	environment.ambient_light_color = Color("aeb7ed") if night else Color("fff1d5")
	environment.ambient_light_energy = 0.65 if night else 0.8
	sun.light_energy = 0.55 if night else 0.9 if rainy else 1.4
	for lamp in lights:
		lamp.light_energy = 1.2 if night else 0.25
	for emitter in rain_emitters:
		emitter.emitting = rainy
	for decor_index in range(theme_decor.size()):
		theme_decor[decor_index].visible = decor_index == index
	shop_sign.text = str(catalog.themes[index].name).to_upper()
	shop_subtitle.text = str(catalog.themes[index].subtitle)

func set_decor(tier: int) -> void:
	for index in range(decorations.size()):
		decorations[index].visible = index < tier

func set_frozen(value: bool) -> void:
	frozen = value
	freeze_animations(self,value)

func freeze_animations(node: Node, value: bool) -> void:
	if node is AnimationPlayer:
		node.speed_scale = 0 if value else 1
	for child in node.get_children():
		freeze_animations(child,value)

func show_shift(skus: Array, chapter: int) -> void:
	home_mode = false
	for neighbor in neighbors: neighbor.queue_free()
	neighbors.clear()
	current_skus = skus.duplicate()
	set_theme(chapter)
	for sku in shelves:
		shelves[sku].visible = sku in skus
		labels[sku].visible = sku in skus
		for marker in markers[sku]:
			marker.visible = sku in skus
	for actor in actors.values(): actor.queue_free()
	for text in actor_labels.values(): text.queue_free()
	actors.clear()
	actor_labels.clear()
	clerk.position = clerk_home

func sync(next_state: Dictionary, delta: float) -> void:
	state = next_state
	if state.is_empty(): return
	for sku in state.shelves:
		var stock := int(state.shelves[sku])
		var capacity := int(state.capacities[sku])
		labels[sku].text = "%s %d/%d" % [catalog.products[sku].name,stock,capacity]
		labels[sku].modulate = Color("ffbf81") if stock == 0 else Color("fff4df")
		for index in range(products[sku].size()):
			products[sku][index].visible = index < int(ceil(float(stock)/capacity*products[sku].size()))
		for index in range(markers[sku].size()):
			markers[sku][index].visible = sku in current_skus and index < stock
	var active: Dictionary = state.active_task
	var clerk_point: Array = state.get("clerk_position",[0,1.35])
	set_actor_position(clerk,Vector3(float(clerk_point[0]),0.04,float(clerk_point[1])),delta)
	var motion := str(state.get("clerk_motion","idle"))
	var desired := "walk" if motion == "walk" else "pick-up" if motion == "interact" and active.get("kind","") == "restock" else "interact-right" if motion == "interact" else "idle"
	animate(clerk,desired)
	for customer in state.customers:
		var id := int(customer.id)
		if not actors.has(id):
			var regular: Dictionary = catalog.regulars[id % catalog.regulars.size()]
			actors[id] = asset(PEOPLE+regular.model+".glb",Vector3(3.2,0.04,3.6),1.2)
			var basket := asset(MARKET+"shopping-basket.glb",Vector3.ZERO,0.55)
			remove_child(basket)
			actors[id].add_child(basket)
			basket.position = Vector3(0,0.28,0.28)
			actors[id].set_meta("basket_model",basket)
			actor_labels[id] = label(str(customer.name),Vector3.ZERO,30)
		var actor: Node3D = actors[id]
		var text: Label3D = actor_labels[id]
		var phase := str(customer.phase)
		var point: Array = customer.get("position",[3.2,3.6])
		set_actor_position(actor,Vector3(float(point[0]),0.04,float(point[1])),delta)
		var customer_motion := str(customer.get("motion_phase","idle"))
		var clip := "walk" if customer_motion == "walk" else "pick-up" if customer_motion == "interact" else "emote-yes" if customer_motion == "celebrate" and phase == "served" else "emote-no" if customer_motion == "celebrate" else "holding-both" if phase == "ready" else "idle"
		animate(actor,clip)
		text.position = actor.position+Vector3(0,1.15,0)
		text.text = str(customer.name)+(" CHECKOUT" if phase == "ready" else "")
		text.modulate = Color("b6f0b4") if phase == "ready" else Color("fff4df")
		actor.visible = customer_motion != "exited"
		var basket_model: Node3D = actor.get_meta("basket_model")
		basket_model.visible = not customer.basket.is_empty()
		text.visible = actor.visible and phase not in ["served","lost"]

func set_actor_position(actor: Node3D, position_value: Vector3, delta: float) -> void:
	# Model time/position is authoritative. Rotation alone is smoothed cosmetically.
	var direction := position_value-actor.position
	if direction.length() > 0.005 and not frozen:
		actor.rotation.y = lerp_angle(actor.rotation.y,atan2(direction.x,direction.z),minf(1,delta*12))
	actor.position = position_value

func select_at(point: Vector2) -> bool:
	if state.is_empty() or frozen: return false
	var nearest := 72.0
	var kind := ""
	var target: Variant = ""
	for sku in current_skus:
		var projected := camera.unproject_position(positions[catalog.sku_order.find(sku)]+Vector3(0,0.6,0))
		var distance := point.distance_to(projected)
		if distance < nearest:
			nearest = distance
			kind = "restock"
			target = sku
	for customer in state.customers:
		if customer.phase == "ready" and actors.has(int(customer.id)):
			var actor: Node3D = actors[int(customer.id)]
			var distance := point.distance_to(camera.unproject_position(actor.position+Vector3(0,0.5,0)))
			if distance < nearest:
				nearest = distance
				kind = "checkout"
				target = int(customer.id)
	if not kind.is_empty():
		target_selected.emit(kind,target)
		return true
	return false

func set_home() -> void:
	show_shift(catalog.sku_order,0)
	home_mode = true
	animate(clerk,"idle")
	for sku in products:
		for product in products[sku]: product.visible = true
		labels[sku].text = str(catalog.products[sku].name)
	for index in range(2):
		var regular: Dictionary = catalog.regulars[index*3]
		var neighbor := asset(PEOPLE+regular.model+".glb",Vector3(-5+index*7,0.02,4.8),1.1)
		animate(neighbor,"walk")
		neighbors.append(neighbor)

func _process(delta: float) -> void:
	if not home_mode or frozen: return
	neighborhood_time += minf(delta,0.1)
	for index in range(neighbors.size()):
		var neighbor: Node3D = neighbors[index]
		var direction := 1.0 if index == 0 else -1.0
		neighbor.position.x = fposmod(neighborhood_time*0.6*direction+index*7+7,14)-7
		neighbor.rotation.y = PI/2 if direction > 0 else -PI/2
