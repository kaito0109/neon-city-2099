class_name FontLoader
extends RefCounted
## Loads TTF fonts that ship inside ModelBlob .tres resources
## (the git snapshot push cannot carry binary files). A real .ttf
## next to the project is preferred when present (local dev).

static var _cache: Dictionary = {}

static func load_font(ttf_path: String, tres_path: String) -> Font:
	if _cache.has(tres_path):
		return _cache[tres_path]
	var bytes := PackedByteArray()
	if FileAccess.file_exists(ttf_path):
		bytes = FileAccess.get_file_as_bytes(ttf_path)
	elif ResourceLoader.exists(tres_path):
		var blob: Resource = ResourceLoader.load(tres_path)
		if blob != null and blob.get("data") != null:
			bytes = blob.get("data")
	var font: Font = null
	if not bytes.is_empty():
		var ff := FontFile.new()
		ff.data = bytes
		if ff.get_string_size("NEON 2099", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x > 0.0:
			font = ff
	_cache[tres_path] = font
	return font
