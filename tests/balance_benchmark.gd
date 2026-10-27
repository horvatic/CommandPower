extends SceneTree

# Reproducible equal-budget, two-side composition sweep. No production/economy gifts
# exist in normal matches; this isolated combat fixture purchases both armies once.
const SIM = preload("res://scripts/simulation.gd")
const DATA = preload("res://scripts/catalog.gd")
const COMPOSITIONS := {
	"combined": {"budget": 2400, "kinds": ["infantry", "skirmisher", "guardian", "lancer", "suppressor", "raider", "destroyer", "medic"]},
	"siege": {"budget": 3200, "kinds": ["tank", "juggernaut", "artillery", "siege_tank", "scout", "medic", "commander"]},
	"mobile": {"budget": 2200, "kinds": ["scout", "skirmisher", "sniper", "shock", "suppressor", "mortar", "disruptor"]}
}

func _initialize() -> void:
	var results: Array = []
	var totals: Dictionary = {}
	for faction: String in DATA.FACTIONS:
		totals[faction] = {"wins": 0, "draws": 0, "matches": 0, "remaining_share": 0.0}
	for first: int in range(DATA.FACTIONS.size()):
		for second: int in range(first + 1, DATA.FACTIONS.size()):
			for composition: String in COMPOSITIONS:
				for reverse: bool in [false, true]:
					var a: String = DATA.FACTIONS[second if reverse else first]
					var b: String = DATA.FACTIONS[first if reverse else second]
					var result: Dictionary = _battle(a, b, composition)
					results.append(result)
					for owner: int in range(2):
						var faction: String = a if owner == 0 else b
						totals[faction].matches += 1
						if result.winner == owner: totals[faction].wins += 1
						if result.winner == -1: totals[faction].draws += 1
						totals[faction].remaining_share += result.remaining[owner]
			print("BALANCE_PAIR ", DATA.FACTIONS[first], " / ", DATA.FACTIONS[second])
	var report: Dictionary = {"budget_scenarios": COMPOSITIONS, "duration_limit_seconds": 45, "mirrored_deployments": true, "totals": totals, "results": results}
	var path := "/tmp/commandpower-balance-results.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): path = argument.trim_prefix("--output=")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("BALANCE_SUMMARY ", JSON.stringify(totals))
	quit()

func _battle(a: String, b: String, composition: String) -> Dictionary:
	var world = SIM.new()
	world.configure_skirmish(a, b)
	world.ai_enabled = false
	world.reset()
	world.entities.clear()
	world.obstacles.clear()
	world.deposits.clear()
	world.wells.clear()
	world._buckets.clear()
	# Keep the normal victory condition alive while isolating the combat fixture.
	world._spawn("hq", 0, Vector2(150, 150))
	world._spawn("hq", 1, Vector2(2900, 1900))
	world._rebuild_navigation()
	var config: Dictionary = COMPOSITIONS[composition]
	var ids: Array = [[], []]
	var spent: Array[int] = [0, 0]
	for owner: int in range(2):
		var remaining: int = int(config.budget)
		var index: int = 0
		var added: bool = true
		while added:
			added = false
			for kind: String in config.kinds:
				var definition: Dictionary = world.spec_for(kind, owner)
				if remaining < int(definition.cost): continue
				var y: float = 950.0 + float(index % 7) * 30.0
				var x: float = 1270.0 - float(index / 7) * 33.0 if owner == 0 else 1730.0 + float(index / 7) * 33.0
				var unit: Dictionary = world._spawn(kind, owner, Vector2(x, y))
				ids[owner].append(unit.id)
				remaining -= int(definition.cost)
				spent[owner] += int(definition.cost)
				index += 1
				added = true
	world._rebuild_buckets()
	world._update_fog()
	world.order_move(ids[0], Vector2(1620, 1040), true)
	world.order_move(ids[1], Vector2(1380, 1040), true)
	var winner: int = -1
	for step: int in range(900):
		world.tick(SIM.STEP)
		var armed: Array[int] = [0, 0]
		for unit: Dictionary in world.entities.values():
			if not bool(world.entity_spec(unit).building) and float(world.entity_spec(unit).damage) > 0.0:
				armed[int(unit.owner)] += 1
		if armed[0] == 0 or armed[1] == 0:
			winner = 0 if armed[0] > 0 else (1 if armed[1] > 0 else -1)
			break
	var remaining_value: Array[float] = [0.0, 0.0]
	for unit: Dictionary in world.entities.values():
		if not bool(world.entity_spec(unit).building):
			remaining_value[int(unit.owner)] += float(world.entity_spec(unit).cost) * maxf(0.0, float(unit.hp)) / float(unit.maxhp)
	return {"a": a, "b": b, "composition": composition, "winner": winner, "seconds": snappedf(world.elapsed, 0.05), "spent": spent, "remaining": [remaining_value[0] / spent[0], remaining_value[1] / spent[1]]}
