extends SceneTree
## Wraps the casino GLBs (assets/models/casino_*.glb) and printed JPGs
## (assets/textures/*.jpg) into ModelBlob .tres files so they can ship
## in the web pck via the snapshot push (which carries no binaries).

const MODELS: Array[String] = [
	"casino_roulette_wheel", "casino_roulette_table", "casino_bj_table",
	"casino_poker_table", "casino_chip", "casino_cage", "casino_chandelier",
	"casino_gate", "casino_slot", "casino_bar", "casino_pitboss",
	"casino_shoe", "casino_stool", "casino_sofa",
]
const TEXTURES: Array[String] = [
	"roulette_layout", "bj_felt", "poker_felt", "casino_carpet",
	"card_atlas", "wheel_ring", "slot_screen",
]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/model_data")
	DirAccess.make_dir_recursive_absolute("res://assets/texture_data")
	var bad: int = 0
	for n in MODELS:
		var src: String = "res://assets/models/" + n + ".glb"
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(src)
		if bytes.is_empty():
			printerr("MISSING ", src)
			bad += 1
			continue
		var blob := ModelBlob.new()
		blob.data = bytes
		var err: Error = ResourceSaver.save(blob, "res://assets/model_data/" + n + ".tres")
		print("saved model ", n, " bytes=", bytes.size(), " err=", err)
	for n in TEXTURES:
		var src2: String = "res://assets/textures/" + n + ".jpg"
		var bytes2: PackedByteArray = FileAccess.get_file_as_bytes(src2)
		if bytes2.is_empty():
			printerr("MISSING ", src2)
			bad += 1
			continue
		var blob2 := ModelBlob.new()
		blob2.data = bytes2
		var err2: Error = ResourceSaver.save(blob2, "res://assets/texture_data/" + n + ".tres")
		print("saved tex ", n, " bytes=", bytes2.size(), " err=", err2)
	quit(1 if bad > 0 else 0)
