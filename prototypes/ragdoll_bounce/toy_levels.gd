class_name ToyLevels

const TITLES := {1: "Mushroom Hill", 2: "The Long Way Home"}
const LENGTHS := {1: "SHORT", 2: "LONG"}


static func title_of(level: int) -> String:
	return TITLES.get(level, "Level %d" % level)


static func name_of(level: int) -> String:
	return "LEVEL %d  -  %s" % [level, title_of(level)]
