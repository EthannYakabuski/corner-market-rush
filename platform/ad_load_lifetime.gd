extends RefCounted
## Game-owned lifetime adapters for the bundled Poing load-reference contract.
## No SDK requests are made by this script until Services calls load().

class Interstitial extends InterstitialAdLoader:
	var _started := false
	var _pending_load := false

	func load(ad_unit_id: String, ad_request: AdRequest, callback := InterstitialAdLoadCallback.new()) -> void:
		if _started or not _plugin:
			return
		_started = true
		_pending_load = true
		super.load(ad_unit_id, ad_request, callback)

	func is_pending_load() -> bool:
		return _pending_load

	func _disconnect_results() -> void:
		safe_disconnect(_plugin, "on_interstitial_ad_loaded", _on_interstitial_ad_loaded)
		safe_disconnect(_plugin, "on_interstitial_ad_failed_to_load", _on_interstitial_ad_failed_to_load)

	func cancel() -> void:
		if not _pending_load:
			return
		var _keep_alive: RefCounted = self
		_pending_load = false
		_disconnect_results()
		interstitial_ad_load_callback = null
		# Balance only the explicit hold acquired by the still-pending load().
		# The ordinary caller/local Ref remains alive until this method returns.
		unreference()

	func _on_interstitial_ad_loaded(uid: int) -> void:
		if uid != _uid or not _pending_load:
			return
		var keep_alive: RefCounted = self
		_pending_load = false
		_disconnect_results()
		super._on_interstitial_ad_loaded(uid)
		# super queues its unreference AFTER the game callback. Keep an owning
		# argument until the following queue entry is destroyed, even if Services
		# was freed reentrantly by that callback. This is not an enduring cycle.
		_release_after_result.call_deferred(keep_alive)

	func _on_interstitial_ad_failed_to_load(uid: int, error: Dictionary) -> void:
		if uid != _uid or not _pending_load:
			return
		var keep_alive: RefCounted = self
		_pending_load = false
		_disconnect_results()
		super._on_interstitial_ad_failed_to_load(uid, error)
		_release_after_result.call_deferred(keep_alive)

	func _release_after_result(_keep_alive: RefCounted) -> void:
		pass

class Rewarded extends RewardedAdLoader:
	var _started := false
	var _pending_load := false

	func load(ad_unit_id: String, ad_request: AdRequest, callback := RewardedAdLoadCallback.new()) -> void:
		if _started or not _plugin:
			return
		_started = true
		_pending_load = true
		super.load(ad_unit_id, ad_request, callback)

	func is_pending_load() -> bool:
		return _pending_load

	func _disconnect_results() -> void:
		safe_disconnect(_plugin, "on_rewarded_ad_loaded", _on_rewarded_ad_loaded)
		safe_disconnect(_plugin, "on_rewarded_ad_failed_to_load", _on_rewarded_ad_failed_to_load)

	func cancel() -> void:
		if not _pending_load:
			return
		var _keep_alive: RefCounted = self
		_pending_load = false
		_disconnect_results()
		rewarded_ad_load_callback = null
		unreference()

	func _on_rewarded_ad_loaded(uid: int) -> void:
		if uid != _uid or not _pending_load:
			return
		var keep_alive: RefCounted = self
		_pending_load = false
		_disconnect_results()
		super._on_rewarded_ad_loaded(uid)
		_release_after_result.call_deferred(keep_alive)

	func _on_rewarded_ad_failed_to_load(uid: int, error: Dictionary) -> void:
		if uid != _uid or not _pending_load:
			return
		var keep_alive: RefCounted = self
		_pending_load = false
		_disconnect_results()
		super._on_rewarded_ad_failed_to_load(uid, error)
		_release_after_result.call_deferred(keep_alive)

	func _release_after_result(_keep_alive: RefCounted) -> void:
		pass
