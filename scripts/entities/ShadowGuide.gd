# 2026-07-07: Stage0でプレイヤーを導き、最後に突き落とす影キャラ。
class_name ShadowGuide
extends Node2D

const SpriteFrameBuilder := preload("res://scripts/core/SpriteFrameBuilder.gd")

var sprite: AnimatedSprite2D # 影キャラ本体。
var eye_flash_tween: Tween # 赤目の強調点滅。
var bite_tween: Tween # タグへ飛びつく噛み演出。

# 影専用スプライトで黒い主人公風の見た目を作る。
func _ready() -> void:
	z_index = 5
	sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = SpriteFrameBuilder.from_folder("res://assets/player_shadow/walk", &"walk", 7.0, true)
	SpriteFrameBuilder.add_animation(sprite.sprite_frames, "res://assets/player_shadow/bite", &"bite", 11.0, false)
	sprite.position = Vector2(0, -22)
	sprite.scale = Vector2(1.35, 1.35)
	sprite.modulate = Color.WHITE
	sprite.play(&"walk")
	add_child(sprite)

	var shadow := Polygon2D.new()
	shadow.name = "Shadow"
	shadow.z_index = -2
	shadow.position = Vector2(0, -1)
	shadow.color = Color(0.0, 0.0, 0.0, 0.5)
	shadow.polygon = PackedVector2Array([Vector2(-18, 0), Vector2(-12, -4), Vector2(0, -6), Vector2(12, -4), Vector2(18, 0), Vector2(12, 4), Vector2(0, 6), Vector2(-12, 4)])
	add_child(shadow)

# 歩行アニメーションへ切り替える。
func play_walk(direction_x: float) -> void:
	sprite.flip_h = direction_x < 0.0
	sprite.play(&"walk")

# 噛みアニメーションへ切り替える。
func play_bite(direction_x: float) -> void:
	sprite.flip_h = direction_x < 0.0
	sprite.play(&"bite")

# 赤目を短く強く光らせる。
func flash_eyes() -> void:
	if eye_flash_tween != null and eye_flash_tween.is_valid():
		eye_flash_tween.kill()
	sprite.modulate = Color(1.45, 0.82, 0.82, 1.0)
	eye_flash_tween = create_tween()
	eye_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.18)

# 指定対象の記憶タグへ飛びつき、接触タイミングを呼び出し側へ返す。
func bite_memory_tag(target: Node, contact_callback: Callable = Callable(), return_to_start := true) -> void:
	if not is_instance_valid(target):
		return
	if bite_tween != null and bite_tween.is_valid():
		bite_tween.kill()
	var start_position := global_position
	var tag_position: Vector2 = target.global_position
	if target.has_method("memory_tag_global_position"):
		tag_position = target.memory_tag_global_position()
	var direction_x := signf(tag_position.x - global_position.x)
	if is_zero_approx(direction_x):
		direction_x = 1.0
	var bite_position := tag_position + Vector2(-18.0 * direction_x, 16.0)
	flash_eyes()
	play_bite(direction_x)
	bite_tween = create_tween()
	bite_tween.set_trans(Tween.TRANS_QUART)
	bite_tween.set_ease(Tween.EASE_OUT)
	bite_tween.tween_property(self, "global_position", bite_position, 0.16)
	bite_tween.tween_callback(func():
		if contact_callback.is_valid():
			contact_callback.call()
	)
	bite_tween.tween_interval(0.10)
	if return_to_start:
		bite_tween.tween_property(self, "global_position", start_position, 0.18)
	bite_tween.tween_callback(func(): play_walk(direction_x))
