class_name TextureLoader
extends RefCounted
## Loads JPG textures that ship inside ModelBlob .tres resources
## (the git snapshot push cannot carry binary files). A real .jpg
## next to the project is preferred when present (local dev).

static var _cache: Dictionary = {}

static func load_tex(jpg_path: String, tres_path: String) -> Texture2D:
	var key: String = tres_path
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	if FileAccess.file_exists(jpg_path):
		var img := Image.new()
		if img.load(jpg_path) == OK:
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
	if tex == null and ResourceLoader.exists(tres_path):
		var blob: Resource = ResourceLoader.load(tres_path)
		if blob != null and blob.get("data") != null:
			var img2 := Image.new()
			if img2.load_jpg_from_buffer(blob.get("data")) == OK:
				img2.generate_mipmaps()
				tex = ImageTexture.create_from_image(img2)
	_cache[key] = tex
	return tex
