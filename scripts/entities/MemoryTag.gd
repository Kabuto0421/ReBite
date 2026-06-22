# 2026-06-13: 記憶タグの表示、点滅、破壊演出を扱う。
class_name MemoryTag
extends Node2D

const PLAQUE_TEXTURE_PATH := "res://assets/ui/memory_tag_plaque.png"
const TOP_FANG_TEXTURE_PATH := "res://assets/ui/bite_hint_top_fang.png"
const BOTTOM_FANG_TEXTURE_PATH := "res://assets/ui/bite_hint_bottom_fang.png"
const KEY_TEXTURE_PATH := "res://assets/ui/bite_hint_key_k.png"
const DASH_LEFT_TEXT_TEXTURE_PATH := "res://assets/ui/memory_text/memory_text_dash_left.png"
const DASH_RIGHT_TEXT_TEXTURE_PATH := "res://assets/ui/memory_text/memory_text_dash_right.png"
const JUMP_TEXT_TEXTURE_PATH := "res://assets/ui/memory_text/memory_text_hop_up.png"
const BITE_TEXT_TEXTURE_PATH := "res://assets/ui/memory_text/memory_text_bite.png"
const SHOOT_LEFT_TEXT_TEXTURE_PATH := "res://assets/ui/memory_text/memory_text_shoot_left.png"
const SHOOT_RIGHT_TEXT_TEXTURE_PATH := "res://assets/ui/memory_text/memory_text_shoot_right.png"
const STOMP_TEXT_TEXTURE_PATH := "res://assets/ui/memory_text/memory_text_stomp_down.png"
const SMASH_TEXT_TEXTURE_PATH := "res://assets/ui/memory_text/memory_text_smash.png"
const HINT_FANG_COLOR := Color("#99e8ff")
const HINT_TINT_STRENGTH := 0.34
const HINT_LAYOUT_TO_GAME_SCALE := 0.5681818
const HINT_FANG_SCALE := 0.4
const HINT_KEY_SCALE := 0.64
const MEMORY_TEXT_SCALE = 0.7
const HINT_PARTS := {
	"top_left": {"texture": TOP_FANG_TEXTURE_PATH, "position": Vector2(-41, -20), "scale": HINT_FANG_SCALE, "flip_h": false, "flip_v": false},
	"top_right": {"texture": TOP_FANG_TEXTURE_PATH, "position": Vector2(41, -20), "scale": HINT_FANG_SCALE, "flip_h": true, "flip_v": false},
	"bottom_left": {"texture": BOTTOM_FANG_TEXTURE_PATH, "position": Vector2(-43, 17), "scale": HINT_FANG_SCALE, "flip_h": true, "flip_v": true},
	"bottom_right": {"texture": BOTTOM_FANG_TEXTURE_PATH, "position": Vector2(43, 17), "scale": HINT_FANG_SCALE, "flip_h": false, "flip_v": true},
	"key": {"texture": KEY_TEXTURE_PATH, "position": Vector2(0, -49), "scale": HINT_KEY_SCALE, "flip_h": false, "flip_v": false},
}

@onready var label: Label = $Label
@onready var crack: Label = $Crack
@onready var plaque: Sprite2D = $Plaque

var text_sprite: Sprite2D

func _ready() -> void:
	plaque.texture = _load_texture(PLAQUE_TEXTURE_PATH)
	_setup_text_sprite()
	_setup_bite_hint_parts()
	set_bite_hint_active(false)
	label.visible = false
	crack.z_index = 4
	visible = false

func show_record(record: Resource) -> void:
	label.text = _to_text(record)
	crack.visible = false
	plaque.visible = true
	label.visible = false
	_apply_text_sprite(record)
	text_sprite.visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE
	set_bite_hint_active(false)
	visible = true

func set_bite_hint_active(active: bool) -> void:
	for child in get_children():
		if child is Sprite2D and String(child.name).begins_with("BiteHint"):
			child.visible = active
	if active:
		plaque.modulate = Color(1.0, 1.0, 1.0, 1.0)

func set_window_progress(progress: float) -> void:
	var clamped: float = clamp(progress, 0.0, 1.0)
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.018) * 0.035
	scale = Vector2(pulse, pulse)
	var urgency: float = 1.0 - clamped
	if clamped < 0.28:
		var blink := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.045)
		plaque.modulate = Color(1.0, 0.45 + blink * 0.45, 0.22, 1.0)
		text_sprite.modulate = Color(1.0, 0.82 + blink * 0.18, 0.4, 1.0)
	else:
		plaque.modulate = Color(1.0, 0.95 + urgency * 0.05, 0.78 + urgency * 0.12, 1.0)
		text_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func crack_tag() -> void:
	_play_stage_sfx(&"memory_tag_crack")
	crack.visible = true
	var tween := create_tween()
	scale = Vector2.ONE
	tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.06)
	tween.tween_property(self, "scale", Vector2.ONE, 0.08)
	tween.tween_interval(0.04)
	tween.tween_callback(hide_tag)
	_emit_tag_shards()

func hide_tag() -> void:
	visible = false

func _to_text(record: Resource) -> String:
	match record.action_name:
		&"dash":
			return "←突進" if record.direction.x < 0.0 else "→突進"
		&"jump":
			return "↑跳躍"
		&"stomp":
			return "↓STOMP↓"
		&"smash":
			return "SMASH"
		_:
			return "???"

func _emit_tag_shards() -> void:
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	var shard_texts: Array[String] = []
	for i in label.text.length():
		shard_texts.append(label.text.substr(i, 1))
	shard_texts.append("◆")
	for i in 12:
		var shard := Label.new()
		shard.text = shard_texts[i % shard_texts.size()]
		shard.add_theme_font_size_override("font_size", 16)
		shard.add_theme_color_override("font_color", Color(1.0, 0.78, 0.22))
		shard.add_theme_color_override("font_shadow_color", Color.BLACK)
		shard.global_position = global_position + Vector2(randf_range(-28, 28), randf_range(-12, 14))
		root.add_child(shard)
		var angle := randf_range(-PI, PI)
		var tween := shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", shard.global_position + Vector2(cos(angle), sin(angle)) * randf_range(36, 82), 0.34)
		tween.tween_property(shard, "modulate:a", 0.0, 0.34)
		tween.set_parallel(false)
		tween.tween_callback(shard.queue_free)

# 現在ステージのSE再生口へ通知する。
func _play_stage_sfx(sound_name: StringName) -> void:
	var root := get_tree().current_scene
	if root != null and root.has_method("play_sfx"):
		root.play_sfx(sound_name)

func _setup_bite_hint_parts() -> void:
	for part_name in HINT_PARTS:
		var config: Dictionary = HINT_PARTS[part_name]
		var sprite := Sprite2D.new()
		sprite.name = "BiteHint%s" % String(part_name).to_pascal_case()
		sprite.texture = _load_bite_hint_texture(config.texture)
		sprite.position = config.position * HINT_LAYOUT_TO_GAME_SCALE
		sprite.scale = Vector2.ONE * float(config.scale)
		sprite.flip_h = config.flip_h
		sprite.flip_v = config.flip_v
		sprite.z_index = 2
		add_child(sprite)

func _setup_text_sprite() -> void:
	text_sprite = Sprite2D.new()
	text_sprite.name = "MemoryText"
	text_sprite.z_index = 3
	text_sprite.visible = false
	text_sprite.scale = Vector2.ONE * MEMORY_TEXT_SCALE
	add_child(text_sprite)

func _apply_text_sprite(record: Resource) -> void:
	text_sprite.texture = _text_texture_for_record(record)
	text_sprite.flip_h = false
	text_sprite.modulate = Color.WHITE

func _text_texture_for_record(record: Resource) -> Texture2D:
	match record.action_name:
		&"dash":
			return _load_texture(DASH_LEFT_TEXT_TEXTURE_PATH if record.direction.x < 0.0 else DASH_RIGHT_TEXT_TEXTURE_PATH)
		&"jump":
			return _load_texture(JUMP_TEXT_TEXTURE_PATH)
		&"bite":
			return _load_texture(BITE_TEXT_TEXTURE_PATH)
		&"shoot":
			return _load_texture(SHOOT_LEFT_TEXT_TEXTURE_PATH if record.direction.x < 0.0 else SHOOT_RIGHT_TEXT_TEXTURE_PATH)
		&"stomp":
			return _load_texture(STOMP_TEXT_TEXTURE_PATH)
		&"smash":
			return _load_texture(SMASH_TEXT_TEXTURE_PATH)
		_:
			return null

func _load_bite_hint_texture(path: String) -> Texture2D:
	if path == KEY_TEXTURE_PATH:
		return _load_texture(path)
	return _load_tinted_texture(path, HINT_FANG_COLOR, HINT_TINT_STRENGTH)

func _load_texture(path: String) -> Texture2D:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Failed to load image: %s" % path)
		return null
	return ImageTexture.create_from_image(image)

func _load_tinted_texture(path: String, tint: Color, strength: float) -> Texture2D:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Failed to load image: %s" % path)
		return null
	var clamped_strength: float = clamp(strength, 0.0, 1.0)
	for y in image.get_height():
		for x in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.0:
				var alpha: float = pixel.a
				pixel = pixel.lerp(tint, clamped_strength)
				pixel.a = alpha
				image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)
