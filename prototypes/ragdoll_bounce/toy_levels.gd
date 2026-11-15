class_name ToyLevels

const TITLES := {1: "Mushroom Hill", 2: "The Long Way Home", 3: "Boulder Run", 4: "Swing Time", 5: "The Gauntlet"}
const LENGTHS := {1: "SHORT", 2: "LONG", 3: "MEDIUM", 4: "MEDIUM", 5: "LONG"}

## How many levels the running game offers (the 2D game has 2, the 3D game 5); each game sets it on start.
static var count := 2


static func title_of(level: int) -> String:
	return TITLES.get(level, "Level %d" % level)


static func name_of(level: int) -> String:
	return "LEVEL %d  -  %s" % [level, title_of(level)]


static func next_of(level: int) -> int:
	return level % count + 1
