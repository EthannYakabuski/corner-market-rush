extends SceneTree
## Isolated synthetic profile fixtures, never a native gameplay or owner save.
const Profile = preload("res://game/profile.gd")
const Model = preload("res://game/market_model.gd")
var count := 0
var path := "user://qa_market_profile_fixture/profile.json"

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error("Assertion failed: " + message)
		quit(1)
		return
	count += 1

func _run() -> void:
	# Only these exact fixture files are removed; no recursive deletion or owner path.
	for suffix in ["", ".bak", ".tmp", ".unreadable", ".bak.unreadable"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	var profile := Profile.new(path)
	check(profile.save(),"fresh fixture saves")
	profile.data.coins = 5
	check(profile.save(),"second fixture saves")
	profile.data.coins = 11
	check(profile.save(),"third fixture saves with previous valid backup")
	var primary := FileAccess.open(path,FileAccess.WRITE)
	primary.store_string("{broken fixture")
	primary.close()
	var recovered := Profile.new(path)
	check(recovered.load_profile(),"corrupt primary recovers actual prior backup")
	check(int(recovered.data.coins) == 5,"backup is previous complete transaction")
	check(FileAccess.file_exists(path+".unreadable"),"unreadable bytes preserved")
	var invalid := Profile.fresh()
	invalid.version = {}
	check(not profile._valid(invalid),"dictionary version rejected without a cast exception")
	invalid = Profile.fresh()
	invalid.coins = NAN
	check(not profile._valid(invalid),"NaN is not progression")
	invalid = Profile.fresh()
	invalid.xp = INF
	check(not profile._valid(invalid),"infinite XP rejected")
	invalid = Profile.fresh()
	invalid.daily = {}
	check(not profile._valid(invalid),"missing daily counters rejected")
	invalid = Profile.fresh()
	invalid.upgrades = {}
	check(not profile._valid(invalid),"missing upgrade schema rejected")
	invalid = Profile.fresh()
	invalid.erase("daily")
	check(not profile._valid(invalid),"erased daily dictionary rejected without exception")
	invalid = Profile.fresh()
	invalid.erase("upgrades")
	check(not profile._valid(invalid),"erased upgrades dictionary rejected without exception")
	invalid = Profile.fresh()
	invalid.upgrades.capacity = 4
	check(not profile._valid(invalid),"upgrade cap enforced in save schema")
	profile.data = Profile.fresh()
	check(profile.claim_login("2026-01-10") == 12,"first calendar reward")
	check(profile.claim_login("2026-01-10") == 0,"same-day calendar idempotence")
	check(profile.claim_login("2026-01-09") == 0,"backwards calendar does not farm")
	check(profile.claim_login("2026-01-12") == 16,"missed day does not punish calendar")
	profile.data = Profile.fresh()
	check(profile.roll_day("2026-01-10"),"new UTC day")
	profile.data.daily.served = 6
	# claim_daily uses actual UTC; fixture tests rollover independently, then aligns.
	profile.roll_day(Profile.today())
	profile.data.daily.served = 6
	check(profile.claim_daily("served") == 15,"earned daily goal claimed")
	check(profile.claim_daily("served") == 0,"daily goal once only")
	check(not profile.roll_day("2020-01-01"),"daily history never moves backwards")
	profile.data.coins = 500
	check(profile.buy_upgrade("capacity"),"capacity purchase")
	check(int(profile.data.upgrades.capacity) == 1 and int(profile.data.coins) == 440,"real cost debited")
	check(not profile.buy_upgrade("unknown"),"unknown upgrade rejected")
	profile.data = Profile.fresh()
	var model := Model.new()
	model.new_shift(1)
	var ticks := 0
	while model.state.status == "active" and ticks < 5000:
		var action: Dictionary = model.baseline_action()
		if not action.is_empty(): model.queue_task(action.kind,action.target)
		model.step(0.1)
		ticks += 1
	check(model.state.status == "won","profile transaction fixture completed via legal model actions")
	profile.data.active = {"model":model.snapshot(),"daily":false}
	var transaction: Dictionary = profile.settle_model(model)
	check(transaction.ok,"bank and progression saved together")
	var coins := int(profile.data.coins)
	var xp := int(profile.data.xp)
	check(coins > 0 and xp > 0 and profile.data.completed.has("1"),"real receipt updates profile")
	check(profile.data.active.is_empty(),"settled active shift cleared")
	var again: Dictionary = profile.settle_model(model)
	check(again.ok and int(profile.data.coins) == coins and int(profile.data.xp) == xp,"repeat settlement cannot duplicate")
	var cold := Profile.new(path)
	check(cold.load_profile(),"cold profile reload")
	var cold_model := Model.new()
	check(cold_model.restore(model.snapshot()),"finished model cold fixture")
	check(cold.settle_model(cold_model).ok and int(cold.data.coins) == coins,"cold repeat settlement cannot duplicate")
	# Impossible directory target simulates an ordinary write failure. No real save.
	var failure := Profile.new("user://qa_market_profile_fixture/profile.json/no-file.json")
	var fresh_model := Model.new()
	fresh_model.new_shift(1)
	fresh_model.restore(model.snapshot())
	fresh_model.state.banked = false
	var failed: Dictionary = failure.settle_model(fresh_model)
	check(not failed.ok and int(failure.data.coins) == 0 and not fresh_model.state.banked,"failed durable write rolls back money and bank flag")
	failure.data.coins = 500
	check(not failure.buy_upgrade("capacity") and int(failure.data.coins) == 500 and int(failure.data.upgrades.capacity) == 0,"failed purchase rolls back coins and tier")
	check(failure.claim_login("2026-01-10") == 0 and failure.data.login_day == "" and int(failure.data.coins) == 500,"failed calendar write cannot report a grant")
	failure.roll_day(Profile.today())
	failure.data.daily.served = 6
	check(failure.claim_daily("served") == 0 and failure.data.daily.claims.is_empty() and int(failure.data.coins) == 500,"failed goal write cannot consume claim or grant coins")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/catalog.json"))
	var badges: Array = profile.check_achievements(catalog)
	check("first_basket" in profile.data.unlocks,"catalog achievement criteria wired")
	check(profile.check_achievements(catalog).is_empty(),"badge claim idempotent")
	check(catalog.achievements.size() == 20 and catalog.leaderboards.size() == 3,"complete stable service mappings")
	print("MARKET PROFILE: %d checks passed (isolated fixtures; not native evidence)" % count)
	quit(0)
