class_name CpUi
extends RefCounted
## Cyberpunk-2077-style UI kit. The game's UI language: panels and
## buttons with 45-degree chamfered corners (the signature is the
## diagonal pair: top-right + bottom-left), 1-2 px borders, near-
## black translucent fills, cyan #00f0ff for data/interactive,
## red #ff003c for danger/titles, signature yellow #fcee0a for the
## primary action, icy #e0f7ff text. StyleBoxFlat cannot cut
## corners, so backgrounds are rasterised into textures at build
## time and wrapped in StyleBoxTexture.

const CYAN := Color(0.0, 0.941, 1.0)
const CYAN_DIM := Color(0.0, 0.55, 0.62)
const RED := Color(1.0, 0.0, 0.235)
const YELLOW := Color(0.988, 0.933, 0.039)
const ICY := Color(0.878, 0.969, 1.0)
const INK := Color(0.008, 0.027, 0.043, 0.80)
const INK_SOLID := Color(0.008, 0.027, 0.043, 0.96)

# Corner bits for chamfer cuts.
const C_TL := 1
const C_TR := 2
const C_BR := 4
const C_BL := 8
const C_DIAG := C_TR + C_BL  # the CP signature pair

static func _inside(p: Vector2, size: Vector2, cut: float, corners: int) -> bool:
	if p.x < 0.0 or p.y < 0.0 or p.x >= size.x or p.y >= size.y:
		return false
	if (corners & C_TL) and p.x + p.y < cut:
		return false
	if (corners & C_TR) and (size.x - 1.0 - p.x) + p.y < cut:
		return false
	if (corners & C_BR) and (size.x - 1.0 - p.x) + (size.y - 1.0 - p.y) < cut:
		return false
	if (corners & C_BL) and p.x + (size.y - 1.0 - p.y) < cut:
		return false
	return true

## Rasterise a chamfered panel: `fill` inside, `border` on the rim.
## `accent` (alpha > 0) paints a short segment of the top edge in a
## second colour, CP-style. `segments` > 0 burns dark divider ticks
## into the fill (segmented bars).
static func chamfer_texture(size: Vector2i, fill: Color, border: Color,
		cut: float = 14.0, border_w: float = 2.5, corners: int = C_DIAG,
		accent: Color = Color(0, 0, 0, 0), segments: int = 0) -> Texture2D:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var sz := Vector2(size)
	var inner := Rect2(Vector2(border_w, border_w), sz - Vector2(border_w, border_w) * 2.0)
	var inner_cut: float = maxf(cut - border_w * 0.8, 1.0)
	var accent_len: float = size.x * 0.22
	for y in range(size.y):
		for x in range(size.x):
			var p := Vector2(x, y)
			if not _inside(p, sz, cut, corners):
				continue
			var col: Color = border
			if inner.has_point(p) and _inside(p - inner.position, inner.size, inner_cut, corners):
				col = fill
				if segments > 0:
					var fx: float = (p.x - inner.position.x) / inner.size.x
					var seg_f: float = fx * float(segments)
					if seg_f - floorf(seg_f) < 0.07:
						col = Color(fill.r * 0.25, fill.g * 0.25, fill.b * 0.25, fill.a)
			elif accent.a > 0.0 and y < int(border_w) + 1 and x > size.x - int(accent_len):
				col = accent
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

static func style(size: Vector2i, fill: Color, border: Color,
		cut: float = 14.0, border_w: float = 2.5, corners: int = C_DIAG,
		accent: Color = Color(0, 0, 0, 0), segments: int = 0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = chamfer_texture(size, fill, border, cut, border_w, corners, accent, segments)
	sb.texture_margin_left = cut + border_w
	sb.texture_margin_right = cut + border_w
	sb.texture_margin_top = cut + border_w
	sb.texture_margin_bottom = cut + border_w
	return sb

## The three states of a CP touch button (74x74): dark ink with a
## coloured rim; pressed = the rim colour floods in, text goes dark.
static func touch_styles(rim: Color) -> Dictionary:
	var n := style(Vector2i(74, 74), INK, rim, 13.0, 3.0)
	var h := style(Vector2i(74, 74), Color(INK.r, INK.g, INK.b, 0.92),
		Color(rim.r, rim.g, rim.b, 1.0), 13.0, 3.5)
	var pr := style(Vector2i(74, 74), rim, rim, 13.0, 3.0)
	var dis := style(Vector2i(74, 74), Color(0.02, 0.03, 0.04, 0.5),
		Color(0.3, 0.35, 0.4, 0.6), 13.0, 2.5)
	return {"normal": n, "hover": h, "pressed": pr, "disabled": dis}
