class_name ToyScores

const MAX := 5

static var enabled := true
static var prefix := "toy"
static var level := 1
## Tests set this to redirect every level to one file; empty means one file per level.
static var path := ""


static func file() -> String:
	if path != "":
		return path
	return "user://%s_scores.cfg" % prefix if level == 1 else "user://%s_scores_%d.cfg" % [prefix, level]


static func load_scores() -> Array:
	if not enabled:
		return []
	var config := ConfigFile.new()
	if config.load(file()) != OK:
		return []
	var data: Array = config.get_value("scores", "data", [])
	return data


static func best() -> float:
	var scores := load_scores()
	return float(scores[0]["time"]) if not scores.is_empty() else 0.0


static func qualifies(time: float) -> bool:
	var scores := load_scores()
	return scores.size() < MAX or time < float(scores[scores.size() - 1]["time"])


## Inserts the run and returns its rank (0-based), or -1 if it did not make the table.
static func add(player_name: String, time: float, kos: int) -> int:
	var scores := load_scores()
	scores.append({"name": player_name, "time": time, "kos": kos})
	scores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"]))
	var rank := -1
	for i in scores.size():
		if scores[i]["time"] == time and scores[i]["name"] == player_name:
			rank = i
			break
	scores = scores.slice(0, MAX)
	if rank >= MAX:
		rank = -1
	if enabled:
		var config := ConfigFile.new()
		config.set_value("scores", "data", scores)
		config.save(file())
	return rank


static func format_time(seconds: float) -> String:
	var m := int(seconds) / 60
	return "%d:%04.1f" % [m, seconds - m * 60]


static func ghost_file() -> String:
	if path != "":
		return path + ".ghost"
	return "user://%s_ghost_%d.dat" % [prefix, level]


static func save_ghost(rec: PackedFloat32Array) -> void:
	if not enabled:
		return
	var f := FileAccess.open(ghost_file(), FileAccess.WRITE)
	if f:
		f.store_var(rec)


static func load_ghost() -> PackedFloat32Array:
	if not enabled or not FileAccess.file_exists(ghost_file()):
		return PackedFloat32Array()
	var f := FileAccess.open(ghost_file(), FileAccess.READ)
	if f == null:
		return PackedFloat32Array()
	var data: Variant = f.get_var()
	return data if data is PackedFloat32Array else PackedFloat32Array()
