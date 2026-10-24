extends RefCounted
## Persistent progression is separate from the deterministic shift simulation.
const VERSION := 1
const SAVE_FILE := "user://corner_market/profile.json"
const SERVICE_UPGRADES := ["restock_apple","restock_bread","restock_milk","restock_cereal","restock_greens","restock_juice","checkout"]
var data: Dictionary = {}
var file_path := SAVE_FILE
var recovery_notice := ""

func _init(path: String = SAVE_FILE) -> void:
	file_path = path
	data = fresh()

static func fresh() -> Dictionary:
	return {"version": VERSION, "coins": 0, "xp": 0, "served": 0, "restocks": 0,
		"best_combo": 0, "perfect_shifts": 0, "completed": {}, "stars": {},
		"regulars": {}, "banked_runs": {}, "accepted_runs": {}, "unlocks": [],
		"upgrades": {"capacity": 0, "reserve": 0, "decor": 0, "restock_apple":0, "restock_bread":0, "restock_milk":0, "restock_cereal":0, "restock_greens":0, "restock_juice":0, "checkout":0}, "active": {},
		"daily": {"day": "", "served": 0, "restocks": 0, "revenue": 0, "claims": [], "won": false},
		"daily_wins": 0, "login_claims": 0, "login_day": "", "music": true, "effects": true,
		"tutorial_seen": false, "best_shift": 0, "completed_rounds": 0}

func load_profile() -> bool:
	for candidate in [file_path, file_path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parsed = _read_json(str(candidate))
		if _valid(parsed):
			var defaults := fresh()
			for key in parsed:
				defaults[key] = parsed[key]
			data = defaults
			for key in SERVICE_UPGRADES:
				if not data.upgrades.has(key): data.upgrades[key] = 0
			if candidate.ends_with(".bak"):
				recovery_notice = "Your backup was recovered safely."
			return true
		# Preserve unreadable bytes before a later successful save replaces the path.
		var preserved: String = str(candidate) + ".unreadable"
		if not FileAccess.file_exists(preserved):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(candidate),ProjectSettings.globalize_path(preserved))
	if FileAccess.file_exists(file_path):
		recovery_notice = "This save could not be read. Your original files were kept."
	return false

func _valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if not value.has("version") or not _safe_number(value.version,VERSION) or int(value.version) != VERSION:
		return false
	for key in ["coins", "xp", "served", "restocks", "best_combo", "perfect_shifts", "daily_wins", "login_claims", "best_shift", "completed_rounds"]:
		if not value.has(key) or not _safe_number(value[key]):
			return false
	for key in ["completed", "stars", "regulars", "banked_runs", "accepted_runs", "upgrades", "active", "daily"]:
		if not value.has(key) or not value[key] is Dictionary:
			return false
	for key in ["capacity", "reserve", "decor"]:
		if not value.upgrades.has(key) or not _safe_number(value.upgrades[key], 3):
			return false
	for key in SERVICE_UPGRADES:
		if value.upgrades.has(key) and not _safe_number(value.upgrades[key],3): return false
	for key in ["served", "restocks", "revenue"]:
		if not value.daily.has(key) or not _safe_number(value.daily[key]):
			return false
	if not value.daily.get("day", null) is String or not value.daily.get("claims", null) is Array or not value.daily.get("won", null) is bool:
		return false
	if not value.get("login_day", null) is String or not value.get("music", null) is bool or not value.get("effects", null) is bool or not value.get("tutorial_seen", null) is bool:
		return false
	for key in value.completed:
		if not str(key).is_valid_int() or int(key) < 1 or int(key) > 36 or value.completed[key] != true:
			return false
	for key in value.stars:
		if not str(key).is_valid_int() or int(key) < 1 or int(key) > 36 or not _safe_number(value.stars[key],3):
			return false
	return value.get("unlocks", null) is Array

func _safe_number(value: Variant, maximum: int = 1000000000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) <= maximum and float(value) == floor(float(value))

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return parser.data

func save() -> bool:
	var dir := ProjectSettings.globalize_path(file_path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return false
	var temporary := file_path + ".tmp"
	var output := FileAccess.open(temporary, FileAccess.WRITE)
	if output == null:
		return false
	output.store_string(JSON.stringify(data))
	output.flush()
	output.close()
	var verify = _read_json(temporary)
	if not _valid(verify):
		return false
	# Keep the previous valid file; never rotate a corrupt primary over the backup.
	if FileAccess.file_exists(file_path):
		var previous = _read_json(file_path)
		if _valid(previous):
			var copy_error := DirAccess.copy_absolute(ProjectSettings.globalize_path(file_path), ProjectSettings.globalize_path(file_path + ".bak"))
			if copy_error != OK:
				return false
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(file_path))
	return error == OK

func level() -> int:
	var result := 1
	while int(data.xp) >= xp_for_level(result + 1):
		result += 1
	return result

static func xp_for_level(value: int) -> int:
	return 45 * value * (value - 1)

static func level_coin_bonus(value: int) -> int:
	return 0 if value < 2 else mini(60, 10 + 5 * value)

func available_shift() -> int:
	var next := 1
	while next <= 36 and data.completed.has(str(next)):
		next += 1
	return mini(36, next)

func upgrade_cost(key: String) -> int:
	return 60 + int(data.upgrades.get(key, 0)) * 90

func buy_upgrade(key: String) -> bool:
	if (not key in ["capacity", "reserve", "decor"] and not key in SERVICE_UPGRADES) or int(data.upgrades.get(key, 0)) >= 3:
		return false
	var cost := upgrade_cost(key)
	if int(data.coins) < cost:
		return false
	var previous: Dictionary = data.duplicate(true)
	data.coins = int(data.coins) - cost
	data.upgrades[key] = int(data.upgrades.get(key, 0)) + 1
	return _commit(previous)

func _commit(previous: Dictionary) -> bool:
	if save():
		return true
	data = previous
	return false

func accept_result(result: Dictionary, shift_state: Dictionary, is_daily: bool = false, daily_day: String = "") -> bool:
	var run := str(result.get("run_id", ""))
	if run.is_empty() or data.accepted_runs.has(run) or bool(result.get("practice", false)):
		return false
	data.accepted_runs[run] = true
	data.completed_rounds = int(data.completed_rounds) + 1
	var won := bool(result.get("won", false))
	var shift := int(result.get("shift_id", 1))
	if won and not is_daily:
		data.completed[str(shift)] = true
		data.stars[str(shift)] = maxi(int(data.stars.get(str(shift), 0)), int(result.get("stars", 1)))
		data.best_shift = maxi(int(data.best_shift), shift)
	if won and int(result.get("lost", 0)) == 0:
		data.perfect_shifts = int(data.perfect_shifts) + 1
	for customer in shift_state.get("customers", []):
		if customer.get("phase", "") == "served":
			data.regulars[str(customer.get("name", "Neighbor"))] = true
	roll_day(today())
	data.daily.served = int(data.daily.served) + int(result.get("served", 0))
	data.daily.restocks = int(data.daily.restocks) + int(result.get("restocks", 0))
	# The daily sales goal counts checkout/completion proceeds, not level gifts.
	data.daily.revenue = int(data.daily.revenue) + int(result.get("base_coins", result.get("coins", 0)))
	if is_daily and won and daily_day == str(data.daily.day) and not bool(data.daily.won):
		data.daily.won = true
		data.daily_wins = int(data.daily_wins) + 1
	data.active = {}
	return save()

func settle_model(model: RefCounted, is_daily: bool = false, daily_day: String = "") -> Dictionary:
	# Bank and result/progression are one durable profile transaction. A failed
	# disk write restores both model and profile so Retry cannot duplicate money.
	var previous: Dictionary = data.duplicate(true)
	var shift_before: Dictionary = model.snapshot()
	var level_before := level()
	var receipt: Dictionary = model.bank_result(data)
	if receipt.is_empty():
		return {"ok":false,"receipt":{}}
	var run := str(receipt.run_id)
	var entry: Dictionary = {}
	if data.banked_runs.get(run) is Dictionary:
		entry = data.banked_runs[run]
	else:
		data.banked_runs[run] = entry
	if bool(receipt.get("claimed", false)):
		receipt["base_coins"] = int(receipt.get("coins", 0))
		var rewards: Array = []
		var bonus := 0
		for new_level: int in range(level_before + 1, level() + 1):
			var coins := level_coin_bonus(new_level)
			rewards.append({"level": new_level, "coins": coins})
			bonus += coins
		receipt["level_bonus"] = bonus
		receipt["level_rewards"] = rewards
		receipt["coins"] = int(receipt.base_coins) + bonus
		data.coins = int(data.coins) + bonus
		entry["receipt"] = receipt.duplicate(true)
	elif entry.get("receipt") is Dictionary:
		# Preserve the original breakdown when the result is reopened or cold
		# loaded. A duplicate reports the old award; it never computes a new one.
		receipt = entry.receipt.duplicate(true)
		receipt["claimed"] = false
	else:
		# Existing version1 saves need no migration or retroactive level grants.
		receipt["base_coins"] = int(receipt.get("coins", 0))
		receipt["level_bonus"] = 0
		receipt["level_rewards"] = []
		entry["receipt"] = receipt.duplicate(true)
	var succeeded := false
	if bool(receipt.get("practice",false)):
		data.active = {}
		succeeded = save()
	elif data.accepted_runs.has(str(receipt.run_id)):
		data.active = {}
		succeeded = save()
	else:
		succeeded = accept_result(receipt,model.state,is_daily,daily_day)
	if not succeeded:
		data = previous
		model.restore(shift_before)
		receipt["claimed"] = false
	return {"ok":succeeded,"receipt":receipt}

static func today() -> String:
	return Time.get_date_string_from_system(true)

func roll_day(day: String) -> bool:
	# Never move the claims calendar backwards when an offline clock is corrected.
	var prior := str(data.daily.get("day", ""))
	if day <= prior:
		return false
	data.daily = {"day": day, "served": 0, "restocks": 0, "revenue": 0, "claims": [], "won": false}
	return true

func daily_shift(day: String) -> int:
	var digits := day.replace("-", "")
	return 1 + (int(digits) % maxi(1, available_shift()))

func claim_login(day: String) -> int:
	if day <= str(data.login_day):
		return 0
	var previous: Dictionary = data.duplicate(true)
	var reward := 12 + (int(data.login_claims) % 7) * 4
	data.login_day = day
	data.login_claims = int(data.login_claims) + 1
	data.coins = int(data.coins) + reward
	return reward if _commit(previous) else 0

func daily_goals() -> Array:
	return [
		{"key":"served", "name":"Six friendly hellos", "target":6, "reward":15},
		{"key":"restocks", "name":"Fresh on the shelf", "target":4, "reward":15},
		{"key":"revenue", "name":"A busy little corner", "target":60, "reward":20}]

func claim_daily(key: String) -> int:
	roll_day(today())
	if key in data.daily.claims:
		return 0
	for goal in daily_goals():
		if goal.key == key and int(data.daily.get(key, 0)) >= int(goal.target):
			var previous: Dictionary = data.duplicate(true)
			data.daily.claims.append(key)
			data.coins = int(data.coins) + int(goal.reward)
			return int(goal.reward) if _commit(previous) else 0
	return 0

func metric(key: String) -> int:
	if key == "level":
		return level()
	if key == "regular_count":
		return data.regulars.size()
	if key == "completed_count":
		return data.completed.size()
	if key.begins_with("chapter_"):
		var chapter := int(key.trim_prefix("chapter_"))
		var count := 0
		for index in range(chapter * 6 + 1, chapter * 6 + 7):
			if data.completed.has(str(index)):
				count += 1
		return count
	return int(data.get(key, 0))

func check_achievements(catalog: Dictionary) -> Array:
	var earned: Array = []
	for achievement in catalog.get("achievements", []):
		if not achievement.key in data.unlocks and metric(achievement.metric) >= int(achievement.target):
			data.unlocks.append(achievement.key)
			earned.append(achievement.key)
	return earned
