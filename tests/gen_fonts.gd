extends SceneTree
## Wraps the Rajdhani TTFs (OFL, Indian Type Foundry) into
## ModelBlob .tres resources so they can ride the text-only git
## snapshot push, like the models and textures.
const BlobScript := preload("res://model_blob.gd")

func _initialize() -> void:
	for pair in [
		["res://assets/fonts/Rajdhani-Bold.ttf", "res://assets/font_data/rajdhani_bold.tres"],
		["res://assets/fonts/Rajdhani-SemiBold.ttf", "res://assets/font_data/rajdhani_semibold.tres"],
	]:
		var blob: Resource = BlobScript.new()
		blob.set("data", FileAccess.get_file_as_bytes(pair[0]))
		var err: int = ResourceSaver.save(blob, pair[1])
		print("saved ", pair[1], " bytes=", blob.get("data").size(), " err=", err)
	quit()
