extends SceneTree
## Keep SDK/Services dependencies out of custom-mainloop preinitialization.
## Only the deferred suite uses local mocks; this is never native reward proof.

func _initialize() -> void:
	_start_suite.call_deferred()

func _start_suite() -> void:
	var suite_script: Script = load("res://tests/support/ad_load_lifetime_suite.gd")
	if suite_script == null or not suite_script.can_instantiate():
		push_error("AD_LOAD_LIFETIME_FAIL: deferred suite did not load")
		quit(2)
		return
	var suite: Node = suite_script.new()
	root.add_child(suite)
