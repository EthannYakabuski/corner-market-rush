extends Node
## Deferred synthetic loader-ownership suite with process-local mock plugin signals.
## Run headless with an isolated user directory and no native plugins.
## These mocks prove GDScript ownership/dispatch only: no native ad, presentation,
## earned callback, entitlement, progress, save, SDK request, or network evidence.
const AdLoads = preload("res://platform/ad_load_lifetime.gd")

# Broad result/content signals let the actual SDK Ad wrappers register normally.
# The mock records calls as values; it never stores loaders or callbacks.
class MockAds extends RefCounted:
	@warning_ignore("unused_signal")
	signal on_interstitial_ad_loaded(uid: int)
	@warning_ignore("unused_signal")
	signal on_interstitial_ad_failed_to_load(uid: int, error: Dictionary)
	@warning_ignore("unused_signal")
	signal on_interstitial_ad_clicked(uid: int)
	@warning_ignore("unused_signal")
	signal on_interstitial_ad_dismissed_full_screen_content(uid: int)
	@warning_ignore("unused_signal")
	signal on_interstitial_ad_failed_to_show_full_screen_content(uid: int, error: Dictionary)
	@warning_ignore("unused_signal")
	signal on_interstitial_ad_impression(uid: int)
	@warning_ignore("unused_signal")
	signal on_interstitial_ad_showed_full_screen_content(uid: int)
	@warning_ignore("unused_signal")
	signal on_interstitial_ad_paid(uid: int, value: Dictionary)
	@warning_ignore("unused_signal")
	signal on_rewarded_ad_loaded(uid: int)
	@warning_ignore("unused_signal")
	signal on_rewarded_ad_failed_to_load(uid: int, error: Dictionary)
	@warning_ignore("unused_signal")
	signal on_rewarded_ad_clicked(uid: int)
	@warning_ignore("unused_signal")
	signal on_rewarded_ad_dismissed_full_screen_content(uid: int)
	@warning_ignore("unused_signal")
	signal on_rewarded_ad_failed_to_show_full_screen_content(uid: int, error: Dictionary)
	@warning_ignore("unused_signal")
	signal on_rewarded_ad_impression(uid: int)
	@warning_ignore("unused_signal")
	signal on_rewarded_ad_showed_full_screen_content(uid: int)
	@warning_ignore("unused_signal")
	signal on_rewarded_ad_paid(uid: int, value: Dictionary)
	@warning_ignore("unused_signal")
	signal on_rewarded_ad_user_earned_reward(uid: int, value: Dictionary)
	var requests: Array[Dictionary] = []
	var destroyed: Array[int] = []
	var next_uid := 100

	func create() -> int:
		next_uid += 1
		return next_uid

	func load(unit_id: String, request: Dictionary, keywords: Array[String], uid: int) -> void:
		requests.append({"unit": unit_id, "request": request, "keywords": keywords.duplicate(), "uid": uid})

	func destroy(uid: int) -> void:
		destroyed.append(uid)

	func deliver(kind: String, uid: int, failed: bool) -> void:
		var stem := "on_interstitial_ad_" if kind == "interstitial" else "on_rewarded_ad_"
		if failed:
			emit_signal(stem + "failed_to_load", uid, {"code": 3, "domain": "fixture", "message": "fixture no fill", "cause": {}, "response_info": {}})
		else:
			emit_signal(stem + "loaded", uid)

# Production handlers and registry run unchanged. _ready prevents config/pending
# reads and native initialization. The last hook allows exit DURING the adapter's
# super callback, before that vendor callback queues its deferred decrement.
class FixtureServices extends "res://platform/services.gd":
	signal terminal_observed(ticket: int)
	var terminal_count := 0
	var retired_before_hook := true

	func _ready() -> void:
		pass

	func _terminal(ticket: int) -> void:
		retired_before_hook = retired_before_hook and not _pending_ad_loaders.has(ticket)
		terminal_count += 1
		terminal_observed.emit(ticket)

	func _interstitial_loaded(ad: InterstitialAd, ticket: int) -> void:
		super._interstitial_loaded(ad, ticket)
		_terminal(ticket)

	func _interstitial_load_failed(error: LoadAdError, ticket: int) -> void:
		super._interstitial_load_failed(error, ticket)
		_terminal(ticket)

	func _rewarded_loaded(ad: RewardedAd, ticket: int) -> void:
		super._rewarded_loaded(ad, ticket)
		_terminal(ticket)

	func _rewarded_load_failed(error: LoadAdError, ticket: int) -> void:
		super._rewarded_load_failed(error, ticket)
		_terminal(ticket)

# This owner removes itself during its active callback, then queues its legal
# deletion BEFORE the vendor queues its decrement. This isolates the adapter
# owning argument from the callback owner without forbidden immediate self-free.
class FreeingOwner extends Node:
	var loader: Variant
	var report: Dictionary

	func begin(kind: String, active_loader: Variant, results: Dictionary) -> WeakRef:
		loader = active_loader
		report = results
		var callback: Variant
		if kind == "interstitial":
			callback = InterstitialAdLoadCallback.new()
		else:
			callback = RewardedAdLoadCallback.new()
		callback.on_ad_loaded = _loaded
		callback.on_ad_failed_to_load = _failed
		loader.load("fixture-only-no-native", AdRequest.new(), callback)
		return weakref(callback)

	func _loaded(ad: Variant) -> void:
		ad.destroy()
		_drop_and_free()

	func _failed(_error: LoadAdError) -> void:
		_drop_and_free()

	func _drop_and_free() -> void:
		report["terminal_count"] = int(report.get("terminal_count", 0)) + 1
		report["terminal_marked_before_callback"] = not loader.is_pending_load()
		loader = null
		get_parent().remove_child(self)
		free.call_deferred()

	func _exit_tree() -> void:
		if is_instance_valid(loader):
			loader.cancel()
		loader = null

var _mock: MockAds
var _saved_plugins: Array = []
var _checks := 0
var _failures: Array[String] = []
var _production_notices := 0
var _reentrant_exits := 0

var root: Window

func _ready() -> void:
	root = get_tree().root
	_run.call_deferred()

func _exit_tree() -> void:
	_restore_plugins()

func quit(code: int) -> void:
	get_tree().quit(code)

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
		push_error("AD_LOAD_LIFETIME_FAIL: " + description)

func _install_plugins() -> void:
	_saved_plugins = [InterstitialAdLoader._plugin, RewardedAdLoader._plugin, InterstitialAd._plugin, RewardedAd._plugin]
	_mock = MockAds.new()
	InterstitialAdLoader._plugin = _mock
	RewardedAdLoader._plugin = _mock
	InterstitialAd._plugin = _mock
	RewardedAd._plugin = _mock

func _restore_plugins() -> void:
	if _saved_plugins.size() != 4:
		return
	InterstitialAdLoader._plugin = _saved_plugins[0]
	RewardedAdLoader._plugin = _saved_plugins[1]
	InterstitialAd._plugin = _saved_plugins[2]
	RewardedAd._plugin = _saved_plugins[3]
	_saved_plugins.clear()
	_mock = null

func _new_loader(kind: String) -> Variant:
	return AdLoads.Interstitial.new() if kind == "interstitial" else AdLoads.Rewarded.new()

func _new_services() -> FixtureServices:
	var node := FixtureServices.new()
	root.add_child(node)
	node.set_process(false)
	node.settings = {"admob": {"interstitial_unit_id": "fixture-interstitial", "rewarded_unit_id": "fixture-rewarded"}}
	node._ads_ready = true
	node._native_ads = false
	return node

func _begin(node: FixtureServices, kind: String) -> Dictionary:
	var previous: Array = node._pending_ad_loaders.keys()
	var request_count := _mock.requests.size()
	if kind == "interstitial":
		node._load_interstitial()
	else:
		node._load_rewarded()
	_check(_mock.requests.size() == request_count + 1, kind + " inherited SDK load reached mock once")
	for ticket in node._pending_ad_loaders:
		if previous.has(ticket):
			continue
		var loader: Variant = node._pending_ad_loaders[ticket]
		var callback: Variant = loader.interstitial_ad_load_callback if kind == "interstitial" else loader.rewarded_ad_load_callback
		return {"ticket": ticket, "uid": int(_mock.requests.back()["uid"]), "loader": weakref(loader), "callback": weakref(callback), "loader_id": loader.get_instance_id(), "callback_id": callback.get_instance_id()}
	_check(false, kind + " loader was retained in the production registry")
	return {}

func _freed(handle: Dictionary, label: String) -> void:
	# A zero-count orphan can make WeakRef.get_ref() return null while its
	# ObjectID is still alive. Short-circuit before WeakRef on that failure.
	_check(not is_instance_id_valid(handle["loader_id"]) and handle["loader"].get_ref() == null, label + " loader deleted from ObjectDB")
	_check(not is_instance_id_valid(handle["callback_id"]) and handle["callback"].get_ref() == null, label + " callback deleted from ObjectDB")

func _observe_notice(_message: String, node_ref: WeakRef, ticket: int) -> void:
	_production_notices += 1
	var node: Variant = node_ref.get_ref()
	_check(is_instance_valid(node) and not node._pending_ad_loaders.has(ticket), "production notice follows ticket retirement")

func _remove_on_terminal(ticket: int, node_ref: WeakRef) -> void:
	var node: Variant = node_ref.get_ref()
	_check(is_instance_valid(node) and not node._pending_ad_loaders.has(ticket), "terminal hook follows ticket retirement")
	if is_instance_valid(node) and node.get_parent() == root:
		root.remove_child(node)
		_reentrant_exits += 1
		_check(node._ads_shutting_down and not node._ads_ready and node._pending_ad_loaders.is_empty(), "reentrant real tree exit completed pending cleanup")

func _test_pending_cancel(kind: String) -> void:
	var node := _new_services()
	var handle := _begin(node, kind)
	if handle.is_empty():
		node.free()
		return
	var before := _mock.requests.size()
	handle["loader"].get_ref().load("must-not-reuse", AdRequest.new())
	_check(_mock.requests.size() == before, kind + " adapter rejects repeated load on the same instance")
	# Queue a terminal native result before cancellation. It must not resurrect it.
	_mock.deliver(kind, handle["uid"], false)
	handle["loader"].get_ref().cancel()
	handle["loader"].get_ref().cancel()
	_check(not handle["loader"].get_ref().is_pending_load(), kind + " repeated cancel is terminal")
	_check(not is_instance_id_valid(handle["callback_id"]) and handle["callback"].get_ref() == null, kind + " cancel clears its callback immediately")
	root.remove_child(node)
	_check(node._pending_ad_loaders.is_empty(), kind + " shutdown retires canceled record")
	_mock.deliver(kind, handle["uid"], true)
	await get_tree().process_frame
	_freed(handle, kind + " pending cancel with queued and late results")
	_check(node.terminal_count == 0, kind + " canceled results never reach game handlers")
	node._exit_tree() # An explicit second cleanup exercises idempotence only.
	node.free()

func _test_wrong_uid(kind: String) -> void:
	var node := _new_services()
	var handle := _begin(node, kind)
	if handle.is_empty():
		node.free()
		return
	_mock.deliver(kind, int(handle["uid"]) + 10000, false)
	_mock.deliver(kind, int(handle["uid"]) + 10000, true)
	await get_tree().process_frame
	_check(node._pending_ad_loaders.has(handle["ticket"]) and handle["loader"].get_ref().is_pending_load(), kind + " unrelated UID preserves pending hold")
	_check(node.terminal_count == 0, kind + " unrelated UID produces no terminal callback")
	node.free()
	await get_tree().process_frame
	_freed(handle, kind + " wrong-UID shutdown")

func _test_result_reentrant(kind: String, failed: bool) -> void:
	var node := _new_services()
	var handle := _begin(node, kind)
	if handle.is_empty():
		node.free()
		return
	node.service_notice.connect(_observe_notice.bind(weakref(node), handle["ticket"]))
	node.terminal_observed.connect(_remove_on_terminal.bind(weakref(node)))
	_mock.deliver(kind, handle["uid"], failed)
	# Already-queued duplicate opposite result must be ignored by terminal state.
	_mock.deliver(kind, handle["uid"], not failed)
	await get_tree().process_frame
	var label := kind + (" failed" if failed else " loaded") + " reentrant exit"
	_check(node.terminal_count == 1 and node.retired_before_hook, label + " invokes game terminal handler exactly once")
	_check(not node.is_inside_tree() and node._ads_shutting_down, label + " occurs before the vendor queues its decrement")
	_freed(handle, label)
	node.free()

func _test_duplicate_registry(kind: String) -> void:
	var node := _new_services()
	var first := _begin(node, kind)
	var second := _begin(node, kind)
	if first.is_empty() or second.is_empty():
		node.free()
		return
	_check(node._pending_ad_loaders.size() == 2 and first["ticket"] != second["ticket"], kind + " concurrent requests retain both loaders")
	_mock.deliver(kind, first["uid"], false)
	await get_tree().process_frame
	_freed(first, kind + " first concurrent result")
	_check(node._pending_ad_loaders.size() == 1 and node._pending_ad_loaders.has(second["ticket"]), kind + " first result preserves other request")
	node.free()
	await get_tree().process_frame
	_freed(second, kind + " second concurrent pending shutdown")

func _test_absent_plugin(kind: String) -> void:
	if kind == "interstitial":
		InterstitialAdLoader._plugin = null
	else:
		RewardedAdLoader._plugin = null
	var before := _mock.requests.size()
	var node := _new_services()
	if kind == "interstitial":
		node._load_interstitial()
	else:
		node._load_rewarded()
	_check(node._pending_ad_loaders.is_empty() and _mock.requests.size() == before, kind + " absent plugin acquires no pending hold")
	var loader: Variant = _new_loader(kind)
	var loader_ref: WeakRef = weakref(loader)
	var loader_id: int = loader.get_instance_id()
	loader.load("absent-fixture-only", AdRequest.new())
	loader.cancel()
	loader.cancel()
	_check(not loader.is_pending_load(), kind + " absent-plugin cancellation is harmless")
	loader = null
	node.free()
	await get_tree().process_frame
	_check(not is_instance_id_valid(loader_id) and loader_ref.get_ref() == null, kind + " absent-plugin adapter deleted from ObjectDB")
	if kind == "interstitial":
		InterstitialAdLoader._plugin = _mock
	else:
		RewardedAdLoader._plugin = _mock

func _test_owner_frees_in_callback(kind: String, failed: bool) -> void:
	var owner := FreeingOwner.new()
	root.add_child(owner)
	var owner_ref: WeakRef = weakref(owner)
	var owner_id: int = owner.get_instance_id()
	var report := {}
	var loader: Variant = _new_loader(kind)
	var loader_ref: WeakRef = weakref(loader)
	var loader_id: int = loader.get_instance_id()
	var callback_ref := owner.begin(kind, loader, report)
	var callback_id: int = callback_ref.get_ref().get_instance_id()
	var uid := int(_mock.requests.back()["uid"])
	loader = null
	_mock.deliver(kind, uid, failed)
	await get_tree().process_frame
	var label := kind + (" failure" if failed else " success") + " owner free"
	_check(not is_instance_id_valid(owner_id) and owner_ref.get_ref() == null, label + " deletes owner before the vendor decrement completes")
	_check(int(report.get("terminal_count", 0)) == 1 and bool(report.get("terminal_marked_before_callback", false)), label + " marks terminal before game callback")
	_check(not is_instance_id_valid(loader_id) and not is_instance_id_valid(callback_id) and loader_ref.get_ref() == null and callback_ref.get_ref() == null, label + " queued owning argument deletes loader and callback afterward")

func _run() -> void:
	if OS.get_name() in ["Android", "iOS"] or DisplayServer.get_name() != "headless":
		push_error("AD_LOAD_LIFETIME_FAIL: reviewed nonmobile headless fixture only")
		quit(2)
		return
	for singleton in ["PoingGodotAdMob", "PoingGodotAdMobInterstitialAd", "PoingGodotAdMobRewardedAd"]:
		if Engine.has_singleton(singleton):
			push_error("AD_LOAD_LIFETIME_FAIL: native plugin detected; mock fixture refused")
			quit(2)
			return
	_install_plugins()
	for kind in ["interstitial", "rewarded"]:
		await _test_pending_cancel(kind)
		await _test_wrong_uid(kind)
		await _test_result_reentrant(kind, false)
		await _test_result_reentrant(kind, true)
		await _test_duplicate_registry(kind)
		await _test_absent_plugin(kind)
		await _test_owner_frees_in_callback(kind, false)
		await _test_owner_frees_in_callback(kind, true)
	_check(_reentrant_exits == 4, "all success/failure tree exits occurred inside terminal callbacks")
	_check(_production_notices >= 2, "actual failure notices observed ticket retirement")
	_restore_plugins()
	print("AD_LOAD_LIFETIME " + JSON.stringify({"checks": _checks, "failures": _failures, "native_or_earned_proof": false, "status": "PASS" if _failures.is_empty() else "FAIL"}))
	quit(0 if _failures.is_empty() else 1)
