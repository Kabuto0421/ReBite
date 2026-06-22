# 2026-06-13: タイル地形の見た目と衝突生成を共有する部品。
class_name TileGroupBuilder
extends RefCounted

const TILE_SIZE := 32 # ステージ上の1タイルの表示サイズ。
const DEFAULT_TILE_TEXTURE_PATH := "res://assets/tiles/dungeon_tileset.png" # 標準タイル画像のパス。
const DEFAULT_ATLAS_REGION := Rect2(Vector2.ZERO, Vector2(16, 16)) # タイル画像から切り出す範囲。

# 生成済みノードをまとめて削除する。
static func clear_generated(parent: Node, group_name := "GeneratedTiles") -> void:
	var generated := parent.get_node_or_null(group_name)
	if generated != null:
		generated.queue_free()

# 生成物を入れる親ノードを作る。
static func create_generated_root(parent: Node, group_name := "GeneratedTiles") -> Node2D:
	clear_generated(parent, group_name)
	var root := Node2D.new()
	root.name = group_name
	parent.add_child(root)
	return root

# 複数の矩形または回転パーツからタイル表示を生成する。
static func build_visuals(parent: Node, tile_parts: Array, modulate := Color.WHITE, group_name := "GeneratedTiles", texture_path := DEFAULT_TILE_TEXTURE_PATH, atlas_region := DEFAULT_ATLAS_REGION) -> Node2D:
	var root := create_generated_root(parent, group_name)
	var texture := load_texture(texture_path)
	if texture == null:
		return root

	for part in tile_parts:
		if not is_valid_part(part):
			continue
		var part_root := Node2D.new()
		part_root.position = part_position(part)
		part_root.rotation = part_rotation(part)
		root.add_child(part_root)
		_build_rect_visuals(part_root, Rect2(Vector2.ZERO, part_size(part)), texture, modulate, atlas_region)
	return root

# 複数の矩形または回転パーツを1つのStaticBody2Dへまとめる。
static func build_static_collision(parent: Node, tile_parts: Array, layer := 1, mask := 0, body_name := "Collision") -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = layer
	body.collision_mask = mask
	parent.add_child(body)

	for part in tile_parts:
		if not is_valid_part(part):
			continue
		var shape_node := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		var size := part_size(part)
		var angle := part_rotation(part)
		shape.size = size
		shape_node.shape = shape
		shape_node.position = part_position(part) + (size * 0.5).rotated(angle)
		shape_node.rotation = angle
		body.add_child(shape_node)
	return body

# 複数の矩形または回転パーツを1つのArea2Dへまとめる。
static func build_area(parent: Node, tile_parts: Array, layer := 0, mask := 0, area_name := "Area") -> Area2D:
	var area := Area2D.new()
	area.name = area_name
	area.collision_layer = layer
	area.collision_mask = mask
	parent.add_child(area)

	for part in tile_parts:
		if not is_valid_part(part):
			continue
		var shape_node := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		var size := part_size(part)
		var angle := part_rotation(part)
		shape.size = size
		shape_node.shape = shape
		shape_node.position = part_position(part) + (size * 0.5).rotated(angle)
		shape_node.rotation = angle
		area.add_child(shape_node)
	return area

# エディタ上へ位置と回転を反映した簡易プレビューを描く。
static func draw_preview(canvas: CanvasItem, tile_parts: Array, fill_color := Color(0.33, 0.13, 0.45), line_color := Color(0.55, 0.22, 0.68)) -> void:
	for part in tile_parts:
		if not is_valid_part(part):
			continue
		var size := part_size(part)
		canvas.draw_set_transform(part_position(part), part_rotation(part), Vector2.ONE)
		var columns := int(ceil(size.x / TILE_SIZE))
		var rows := int(ceil(size.y / TILE_SIZE))
		for y in rows:
			for x in columns:
				var tile_rect := Rect2(Vector2(x * TILE_SIZE, y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
				canvas.draw_rect(tile_rect, fill_color, true)
				canvas.draw_rect(tile_rect.grow(-2.0), line_color, false, 2.0)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ファイルパスから画像テクスチャを読み込む。
static func load_texture(path: String) -> Texture2D:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Failed to load image: %s" % path)
		return null
	return ImageTexture.create_from_image(image)

# AtlasTextureを作る。
static func atlas(texture: Texture2D, region: Rect2 = DEFAULT_ATLAS_REGION) -> AtlasTexture:
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = texture
	atlas_texture.region = region
	return atlas_texture

# 生成対象にできる実サイズの矩形か判定する。
static func is_valid_rect(rect: Rect2) -> bool:
	return rect.size.x > 0.0 and rect.size.y > 0.0

# 矩形または回転パーツが生成可能なサイズを持つか返す。
static func is_valid_part(part: Variant) -> bool:
	var size := part_size(part)
	return size.x > 0.0 and size.y > 0.0

# 矩形または回転パーツの左上位置を返す。
static func part_position(part: Variant) -> Vector2:
	if part is Rect2:
		return (part as Rect2).position
	if part is Dictionary:
		var data: Dictionary = part
		var value: Variant = data.get("position", Vector2.ZERO)
		if value is Vector2:
			return value
	return Vector2.ZERO

# 矩形または回転パーツのサイズを返す。
static func part_size(part: Variant) -> Vector2:
	if part is Rect2:
		return (part as Rect2).size
	if part is Dictionary:
		var data: Dictionary = part
		var value: Variant = data.get("size", Vector2.ZERO)
		if value is Vector2:
			return value
	return Vector2.ZERO

# 矩形または回転パーツの回転角度を返す。
static func part_rotation(part: Variant) -> float:
	if part is Dictionary:
		var data: Dictionary = part
		var value: Variant = data.get("rotation", 0.0)
		if value is float or value is int:
			return float(value)
	return 0.0

# 1矩形ぶんのタイル表示を生成する。
static func _build_rect_visuals(parent: Node, rect: Rect2, texture: Texture2D, modulate := Color.WHITE, atlas_region := DEFAULT_ATLAS_REGION) -> void:
	var columns := int(ceil(rect.size.x / TILE_SIZE))
	var rows := int(ceil(rect.size.y / TILE_SIZE))
	for y in rows:
		for x in columns:
			var sprite := Sprite2D.new()
			sprite.texture = atlas(texture, atlas_region)
			sprite.scale = Vector2(2.0, 2.0)
			sprite.modulate = modulate
			sprite.position = rect.position + Vector2(x * TILE_SIZE + TILE_SIZE * 0.5, y * TILE_SIZE + TILE_SIZE * 0.5)
			parent.add_child(sprite)
