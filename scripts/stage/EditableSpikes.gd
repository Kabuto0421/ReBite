# 2026-06-13: ステージ編集用の針トラップ。
@tool
class_name EditableSpikes
extends Node2D

@export var size := Vector2(96, 32)
@export var points_down := false

const SPIKE_SIZE := 32
const SPIKE_TEXTURE_PATH := "res://assets/tiles/dungeon_tileset.png"
const SPIKE_ATLAS_REGION := Rect2(Vector2(32, 96), Vector2(16, 16))

var _last_size := Vector2.ZERO
var _last_points_down := false
var _spike_texture: Texture2D

func _ready() -> void:
	_spike_texture = _load_texture(SPIKE_TEXTURE_PATH)
	_last_size = size
	_last_points_down = points_down
	queue_redraw()
	if not Engine.is_editor_hint():
		_build_area()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and (_last_size != size or _last_points_down != points_down):
		_last_size = size
		_last_points_down = points_down
		queue_redraw()

func _draw() -> void:
	if _spike_texture == null:
		return
	var count := int(size.x / SPIKE_SIZE)
	for i in count:
		var base_x := i * SPIKE_SIZE
		if points_down:
			draw_set_transform(Vector2(base_x + SPIKE_SIZE, SPIKE_SIZE), PI, Vector2(2.0, 2.0))
			draw_texture_rect_region(_spike_texture, Rect2(Vector2.ZERO, SPIKE_ATLAS_REGION.size), SPIKE_ATLAS_REGION)
		else:
			draw_set_transform(Vector2(base_x, 0.0), 0.0, Vector2(2.0, 2.0))
			draw_texture_rect_region(_spike_texture, Rect2(Vector2.ZERO, SPIKE_ATLAS_REGION.size), SPIKE_ATLAS_REGION)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _build_area() -> void:
	_build_visuals()

	var area := Area2D.new()
	area.name = "DamageArea"
	area.collision_mask = 6
	area.body_entered.connect(_on_body_entered)
	add_child(area)

	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.position = size * 0.5
	area.add_child(shape_node)

func _build_visuals() -> void:
	var visual_root := Node2D.new()
	visual_root.name = "SpikeVisuals"
	add_child(visual_root)
	var count := int(size.x / SPIKE_SIZE)
	for i in count:
		var sprite := Sprite2D.new()
		sprite.texture = _spike_atlas()
		sprite.centered = true
		sprite.scale = Vector2(2.0, 2.0)
		sprite.flip_v = points_down
		sprite.position = Vector2(i * SPIKE_SIZE + SPIKE_SIZE * 0.5, SPIKE_SIZE * 0.5)
		visual_root.add_child(sprite)

func _spike_atlas() -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = _spike_texture
	atlas.region = SPIKE_ATLAS_REGION
	return atlas

func _load_texture(path: String) -> Texture2D:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Failed to load image: %s" % path)
		return null
	return ImageTexture.create_from_image(image)

func _on_body_entered(body: Node) -> void:
	var root := get_tree().current_scene
	if root != null and root.has_method("handle_spike_body_entered"):
		root.handle_spike_body_entered(body, body.global_position)
		return
	if body.has_method("die"):
		body.die()
	elif body.has_method("reset_to_spawn"):
		body.reset_to_spawn()
