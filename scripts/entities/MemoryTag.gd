# 2026-06-13: 記憶タグの表示、点滅、破壊演出を扱う。
class_name MemoryTag
extends Node2D

const DeviceProfileScript := preload("res://scripts/platform/DeviceProfile.gd")

signal lifecycle_changed(previous: int, current: int)
signal memory_consumed(memory_id: int)
signal memory_injected(direction: Vector2, memory_id: int)
signal memory_reformed(memory_id: int)

enum Lifecycle { NONE, AVAILABLE, BREAKING, REPLAYING, REFORMING }

const PLAQUE_TEXTURE_PATH := "res://assets/ui/memory_tag_plaque.png"
const TOP_FANG_TEXTURE_PATH := "res://assets/ui/bite_hint_top_fang.png"
const BOTTOM_FANG_TEXTURE_PATH := "res://assets/ui/bite_hint_bottom_fang.png"
const KEY_TEXTURE_PATH := "res://assets/ui/bite_hint_key_k.png"
const MOBILE_BITE_ICON_TEXTURE_PATH := "res://assets/ui/mobile/mobile_bite_button.png"
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

@export_range(0.2, 0.9, 0.05) var blink_start_progress := 0.70 # タグ更新までの残り割合がこの値を下回ると点滅する。

@onready var label: Label = $Label
@onready var crack: Label = $Crack
@onready var plaque: Sprite2D = $Plaque

var text_sprite: Sprite2D
var lifecycle: Lifecycle = Lifecycle.NONE
var visual_tween: Tween
var window_progress := 1.0 # 現在行動がタグ更新へ近づいている割合。

func _ready() -> void:
	plaque.texture = _load_texture(PLAQUE_TEXTURE_PATH)
	_setup_text_sprite()
	_setup_bite_hint_parts()
	set_bite_hint_active(false)
	label.visible = false
	crack.z_index = 4
	visible = false

func show_record(record: Resource) -> void:
	_kill_visual_tween()
	if record != null:
		record.is_available = true
	label.text = _to_text(record)
	crack.visible = false
	plaque.visible = true
	label.visible = false
	_apply_text_sprite(record)
	text_sprite.visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE
	plaque.modulate = Color.WHITE
	text_sprite.modulate = Color.WHITE
	window_progress = 1.0
	set_bite_hint_active(false)
	visible = true
	_set_lifecycle(Lifecycle.AVAILABLE)

# 噛み成立後の破壊と方向流入を短時間で再生する。
func begin_breaking(record: Resource) -> void:
	if lifecycle != Lifecycle.AVAILABLE:
		return
	if record != null:
		record.is_available = false
		memory_consumed.emit(record.memory_id)
	_set_lifecycle(Lifecycle.BREAKING)
	set_bite_hint_active(false)
	crack.visible = true
	label.text = "←" if record != null and record.direction.x < 0.0 else "→"
	label.visible = false
	visual_tween = create_tween()
	visual_tween.tween_property(self, "scale", Vector2(0.88, 1.08), 0.04)
	visual_tween.tween_callback(_show_direction_only)
	visual_tween.tween_interval(0.04)
	visual_tween.tween_callback(_emit_arrow_afterimage)
	visual_tween.tween_property(label, "position:y", 11.0, 0.07)
	visual_tween.parallel().tween_property(label, "scale", Vector2(0.68, 0.68), 0.07)
	visual_tween.tween_callback(_emit_arrow_afterimage)
	visual_tween.tween_property(label, "position:y", 35.0, 0.07)
	visual_tween.parallel().tween_property(label, "scale", Vector2(0.34, 0.34), 0.07)
	visual_tween.tween_callback(Callable(self, "_emit_memory_injected").bind(record))
	visual_tween.tween_property(label, "modulate:a", 0.0, 0.025)
	visual_tween.tween_callback(mark_replaying)
	_emit_tag_shards()

# 再演中の表示なし状態へ切り替える。
func mark_replaying() -> void:
	_set_lifecycle(Lifecycle.REPLAYING)
	visible = false

# 完了した再演記憶を短い生成演出後に再び噛める状態へ戻す。
func reform_record(record: Resource) -> void:
	_kill_visual_tween()
	_set_lifecycle(Lifecycle.REFORMING)
	label.text = _to_text(record)
	crack.visible = false
	plaque.visible = true
	label.visible = false
	_apply_text_sprite(record)
	text_sprite.visible = true
	text_sprite.modulate = Color.WHITE
	plaque.modulate = Color.WHITE
	modulate = Color.WHITE
	scale = Vector2(0.72, 0.72)
	visible = true
	visual_tween = create_tween()
	visual_tween.set_trans(Tween.TRANS_BACK)
	visual_tween.set_ease(Tween.EASE_OUT)
	visual_tween.tween_property(self, "scale", Vector2.ONE, 0.09)
	visual_tween.tween_callback(Callable(self, "_finish_reform").bind(record))

# 現在タグを噛めるか返す。
func is_available() -> bool:
	return lifecycle == Lifecycle.AVAILABLE

func set_bite_hint_active(active: bool) -> void:
	for child in get_children():
		if child is Sprite2D and String(child.name).begins_with("BiteHint"):
			child.visible = active
	if active:
		plaque.modulate = Color(1.0, 1.0, 1.0, 1.0)

func set_window_progress(progress: float) -> void:
	var clamped: float = clamp(progress, 0.0, 1.0)
	window_progress = clamped
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.018) * 0.035
	scale = Vector2(pulse, pulse)
	var urgency: float = 1.0 - clamped
	if clamped < blink_start_progress:
		var blink := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.045)
		plaque.modulate = Color(1.0, 0.45 + blink * 0.45, 0.22, 1.0)
		text_sprite.modulate = Color(1.0, 0.82 + blink * 0.18, 0.4, 1.0)
	else:
		plaque.modulate = Color(1.0, 0.95 + urgency * 0.05, 0.78 + urgency * 0.12, 1.0)
		text_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func crack_tag() -> void:
	_kill_visual_tween()
	_set_lifecycle(Lifecycle.BREAKING)
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
	_set_lifecycle(Lifecycle.NONE)

func _show_direction_only() -> void:
	plaque.visible = false
	text_sprite.visible = false
	crack.visible = false
	label.position = Vector2(-43.0, -13.0)
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE
	label.modulate = Color(1.0, 0.9, 0.42, 1.0)
	label.visible = true

# 流入中の方向矢印へ短い残像を追加する。
func _emit_arrow_afterimage() -> void:
	var afterimage := Label.new()
	afterimage.text = label.text
	afterimage.position = label.position
	afterimage.size = label.size
	afterimage.pivot_offset = label.pivot_offset
	afterimage.scale = label.scale
	afterimage.z_index = label.z_index - 1
	afterimage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	afterimage.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	afterimage.add_theme_font_size_override("font_size", 15)
	afterimage.add_theme_color_override("font_color", Color(1.0, 0.72, 0.18, 0.72))
	afterimage.add_theme_color_override("font_shadow_color", Color.BLACK)
	add_child(afterimage)
	var tween := afterimage.create_tween()
	tween.set_parallel(true)
	tween.tween_property(afterimage, "position:y", afterimage.position.y + 8.0, 0.12)
	tween.tween_property(afterimage, "modulate:a", 0.0, 0.12)
	tween.set_parallel(false)
	tween.tween_callback(afterimage.queue_free)

# 矢印が敵本体へ到達したことを所有者へ通知する。
func _emit_memory_injected(record: Resource) -> void:
	if record != null:
		memory_injected.emit(record.direction, record.memory_id)

func _finish_reform(record: Resource) -> void:
	if record != null:
		record.is_available = true
	_set_lifecycle(Lifecycle.AVAILABLE)
	memory_reformed.emit(record.memory_id if record != null else 0)

func _set_lifecycle(next: Lifecycle) -> void:
	if lifecycle == next:
		return
	var previous := lifecycle
	lifecycle = next
	lifecycle_changed.emit(previous, lifecycle)

func _kill_visual_tween() -> void:
	if visual_tween != null and visual_tween.is_valid():
		visual_tween.kill()
	visual_tween = null

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
	var shard_texts: Array[String] = ["◆", "◇", "▪"]
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

func _setup_bite_hint_parts() -> void:
	for part_name in HINT_PARTS:
		var config: Dictionary = HINT_PARTS[part_name]
		var sprite := Sprite2D.new()
		sprite.name = "BiteHint%s" % String(part_name).to_pascal_case()
		if part_name == "key" and DeviceProfileScript.should_use_touch_bite_hint():
			sprite.texture = _load_texture(MOBILE_BITE_ICON_TEXTURE_PATH)
			sprite.position = Vector2(0, -31)
			sprite.scale = Vector2.ONE * 0.18
		else:
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
