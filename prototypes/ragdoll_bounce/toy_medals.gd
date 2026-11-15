class_name ToyMedals

# seconds to beat: [gold, silver, bronze]
const TIMES := {1: [10.0, 13.0, 15.0], 2: [55.0, 60.0, 70.0]}
const NAMES := ["NO MEDAL", "BRONZE", "SILVER", "GOLD"]


static func times(level: int) -> Array:
	return TIMES.get(level, TIMES[1])


## time to beat for a medal tier (3 = gold, 2 = silver, 1 = bronze)
static func tier_time(level: int, tier: int) -> float:
	return float(times(level)[3 - tier])


## 0 = none, 1 = bronze, 2 = silver, 3 = gold
static func medal(level: int, time: float) -> int:
	for tier in [3, 2, 1]:
		if time <= tier_time(level, tier):
			return tier
	return 0


static func next_target(level: int, time: float) -> float:
	for tier in [1, 2, 3]:
		if time > tier_time(level, tier):
			return tier_time(level, tier)
	return 0.0
