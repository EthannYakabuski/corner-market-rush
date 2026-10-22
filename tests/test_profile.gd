extends SceneTree
## Isolated synthetic profile fixtures, never a native gameplay or owner save.
const Profile = preload("res://game/profile.gd")
const Model = preload("res://game/market_model.gd")
var count := 0
var failures := 0
var path := "user://qa_market_profile_fixture/profile.json"

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	count += 1
	if not condition:
		failures += 1
		push_error("Assertion failed: " + message)

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
	check(int(transaction.receipt.base_coins) == 28 and int(transaction.receipt.coins) == 28 and int(transaction.receipt.xp) == 35 and int(transaction.receipt.level_bonus) == 0 and transaction.receipt.level_rewards.is_empty(),"first shift at zero XP retains original28coin35XP receipt without level reward")
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
	_test_level_coin_transaction()
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
	print("MARKET PROFILE %s: %d checks, %d failures (isolated fixtures; not native evidence)" % ["PASS" if failures == 0 else "FAILED",count,failures])
	quit(0 if failures == 0 else 1)

func _finish_legal_shift(model: RefCounted) -> void:
	model.new_shift(1)
	var ticks := 0
	while model.state.status == "active" and ticks < 5000:
		var action: Dictionary = model.baseline_action()
		if not action.is_empty():
			model.queue_task(action.kind, action.target)
		model.step(0.1)
		ticks += 1
	check(model.state.status == "won", "level fixture completes actual legal restock/checkout sequence")

func _test_level_coin_transaction() -> void:
	# XP80 is a deliberately seeded synthetic source fixture. It never enters
	# the genuine native profile or claims evidence of earned player progress.
	var level_path := "user://qa_market_profile_fixture/level_bonus.json"
	var leveled := Profile.new(level_path)
	leveled.data.xp = 80
	check(leveled.save(), "isolated XP80 fixture saves before the transaction")
	var level_model := Model.new()
	_finish_legal_shift(level_model)
	var settled: Dictionary = leveled.settle_model(level_model)
	var receipt: Dictionary = settled.receipt
	check(settled.ok and bool(receipt.claimed), "first crossing settles once")
	check(leveled.level() == 2 and int(leveled.data.xp) == 115, "legal35XP shift crosses manager level2 at90XP")
	check(int(receipt.base_coins) == 28 and int(receipt.level_bonus) == 20 and int(receipt.coins) == 48, "receipt separates base sale and real level bonus")
	check(receipt.level_rewards.size() == 1 and int(receipt.level_rewards[0].level) == 2 and int(receipt.level_rewards[0].coins) == 20, "receipt names the exact rewarded level")
	check(int(leveled.data.coins) == 48 and int(leveled.data.daily.revenue) == 28, "wallet receives bonus while daily sales count only base proceeds")
	var run := str(receipt.run_id)
	check(leveled.data.banked_runs[run].receipt.has_all(["base_coins", "level_bonus", "level_rewards", "coins"]), "original breakdown cached in existing run ledger")
	var repeated: Dictionary = leveled.settle_model(level_model)
	check(repeated.ok and not bool(repeated.receipt.claimed) and int(repeated.receipt.level_bonus) == 20 and int(repeated.receipt.coins) == 48, "repeat reports original breakdown without another claim")
	check(int(leveled.data.coins) == 48 and int(leveled.data.xp) == 115, "repeat cannot credit sale XP or level coins again")
	var cold := Profile.new(level_path)
	check(cold.load_profile(), "level transaction cold-loads from actual fixture bytes")
	var cold_model := Model.new()
	check(cold_model.restore(level_model.snapshot()), "settled level model cold-loads")
	var cold_repeat: Dictionary = cold.settle_model(cold_model)
	check(cold_repeat.ok and not bool(cold_repeat.receipt.claimed) and int(cold_repeat.receipt.level_bonus) == 20 and cold_repeat.receipt.level_rewards.size() == 1, "cold repeat retains exact original level receipt")
	check(int(cold.data.coins) == 48 and int(cold.data.xp) == 115, "cold repeat cannot duplicate level coins")
	# Existing version1 run entries without a receipt remain valid and never
	# receive a retroactive grant merely because the new code is loaded.
	cold.data.banked_runs[run].erase("receipt")
	check(cold._valid(cold.data), "legacy version1 run ledger needs no new mandatory field")
	var legacy_repeat: Dictionary = cold.settle_model(cold_model)
	check(legacy_repeat.ok and not bool(legacy_repeat.receipt.claimed) and int(legacy_repeat.receipt.level_bonus) == 0 and int(cold.data.coins) == 48, "legacy receipt has zero retroactive level credit")
	check(Profile.level_coin_bonus(1) == 0 and Profile.level_coin_bonus(2) == 20 and Profile.level_coin_bonus(99) == 60, "level reward is modest and capped")
	# This exact fixture parent is a file created earlier, so the requested
	# directory cannot be written. Only in-memory fixture state is rolled back.
	var failure := Profile.new("user://qa_market_profile_fixture/profile.json/level_bonus.json")
	failure.data.xp = 80
	var failure_model := Model.new()
	_finish_legal_shift(failure_model)
	var failed: Dictionary = failure.settle_model(failure_model)
	check(not failed.ok and not bool(failed.receipt.claimed), "failed level transaction reports no completed claim")
	check(int(failure.data.coins) == 0 and int(failure.data.xp) == 80 and failure.data.banked_runs.is_empty() and failure.data.accepted_runs.is_empty(), "failed save rolls back base sale XP level coins and ledgers together")
	check(not bool(failure_model.state.banked), "failed save rolls model bank flag back for a safe retry")
