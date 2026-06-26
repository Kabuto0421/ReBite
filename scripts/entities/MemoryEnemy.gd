# 2026-06-13: 記憶タグを持つ敵の共通処理。
class_name MemoryEnemy
extends "res://scripts/entities/Character.gd"

signal died # 死亡演出完了後にステージへ通知する。

const REPLAY_OUTLINE_SHADER := preload("res://assets/shaders/skull_pixel_outline.gdshader")

@export_group("Replay Visual")
@export var replay_outline_color := Color("#c86bff") # 再演中だけ表示する明るい紫の輪郭色。
@export_range(1.0, 4.0, 0.05) var replay_outline_size := 1.65 # 再演中の輪郭太さ。

var last_record: Resource # 最後に記憶タグへ保存した行動。
var active_action_record: Resource # 現在実行中で地形ギミックに伝える行動。
var next_memory_id := 1 # 次に保存する記憶の識別子。
var default_outline_color := Color.TRANSPARENT # 通常時の輪郭色。
var default_outline_size := 0.0 # 通常時の輪郭太さ。
var default_tint_color := Color.WHITE # 通常時に各敵へ設定されている本体色。

@onready var memory_tag: Node = $MemoryTag # 敵の頭上に出る記憶タグ。
@onready var attack_hitbox: Area2D = $AttackHitbox # 攻撃中だけ有効になる当たり判定。

# 記憶敵に共通する初期化を行う。
func setup_memory_enemy() -> void:
	add_to_group(&"memory_enemy")
	remember_spawn_position()
	_setup_replay_outline_material()
	attack_hitbox.collision_mask |= 1
	attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	set_attack_hitbox_active(false)

# 通常の噛み受付から記憶再演へ入る。
func receive_bite(_player: Node) -> void:
	if last_record == null or not is_biteable():
		return
	state_machine.change_state(&"Recalled", last_record)

# 噛み開始時に確定した記憶で再演へ入る。
func receive_committed_bite(_player: Node, record: Resource = null) -> bool:
	if current_state_name() == &"Dying":
		return false
	if record == null:
		record = last_record
	if record == null:
		return false
	state_machine.change_state(&"Recalled", record)
	return true

# K入力フレームで記憶再演を確定する共通入口。
func begin_committed_bite(player: Node, record: Resource) -> bool:
	if not is_biteable():
		return false
	return receive_committed_bite(player, record)

# 完了した行動を新しい利用可能な記憶として保存する。
func commit_memory_record(record: Resource, source_type: StringName = &"NATURAL", reform := false) -> void:
	last_record = record
	if last_record == null:
		return
	last_record.mark_as_memory(next_memory_id, source_type)
	next_memory_id += 1
	if reform and memory_tag.has_method("reform_record"):
		last_record.is_available = false
		memory_tag.reform_record(last_record)
	else:
		memory_tag.show_record(last_record)

# 保存中の記憶を使用済みにし、タグ破壊演出を開始する。
func consume_memory_record(record: Resource) -> bool:
	if record == null or record != last_record or not record.is_available:
		return false
	if memory_tag.has_method("is_available") and not memory_tag.is_available():
		return false
	record.is_available = false
	if memory_tag.has_method("begin_breaking"):
		memory_tag.begin_breaking(record)
	else:
		memory_tag.crack_tag()
	return true

# 噛み開始時に固定する記憶を返す。
func bite_commit_record() -> Resource:
	return last_record

# 現在実行中の行動記録を返す。
func current_action_record() -> Resource:
	return active_action_record

# 地形ギミックへ通知する現在行動を設定する。
func set_active_action_record(record: Resource) -> void:
	active_action_record = record

# 地形ギミックへ通知する現在行動を解除する。
func clear_active_action_record(record: Resource = null) -> void:
	if record == null or active_action_record == record:
		active_action_record = null

# 現在噛める状態かを返す。
func is_biteable() -> bool:
	return last_record != null and last_record.is_available and memory_tag.visible and current_state_name() == &"Recover"

# 噛みカメラが注目するタグ位置を返す。
func memory_tag_global_position() -> Vector2:
	return memory_tag.global_position

# 予測矢印の対象になっている間だけタグの噛み案内を強調する。
func set_memory_bite_hint_active(active: bool) -> void:
	if memory_tag != null and memory_tag.has_method("set_bite_hint_active"):
		memory_tag.set_bite_hint_active(active)

# 攻撃判定の有効/無効を切り替える。
func set_attack_hitbox_active(active: bool) -> void:
	attack_hitbox.set_deferred("monitoring", active)
	attack_hitbox.set_deferred("monitorable", active)

# 再演中の紫輪郭を個体専用Materialへ適用・解除する。
func set_replay_outline_active(active: bool) -> void:
	var shader_material := sprite.material as ShaderMaterial
	if shader_material == null:
		return
	if active:
		sprite.modulate = Color.WHITE
	shader_material.set_shader_parameter("outline_color", replay_outline_color if active else default_outline_color)
	shader_material.set_shader_parameter("outline_size", replay_outline_size if active else default_outline_size)
	shader_material.set_shader_parameter("tint_color", Color.WHITE if active else default_tint_color)

# 既存Materialを複製し、未設定の敵には通常色を変えない輪郭Shaderを用意する。
func _setup_replay_outline_material() -> void:
	var source_material := sprite.material as ShaderMaterial
	var instance_material: ShaderMaterial
	if source_material != null and source_material.shader == REPLAY_OUTLINE_SHADER:
		instance_material = source_material.duplicate() as ShaderMaterial
		default_outline_color = instance_material.get_shader_parameter("outline_color") as Color
		default_outline_size = float(instance_material.get_shader_parameter("outline_size"))
		default_tint_color = instance_material.get_shader_parameter("tint_color") as Color
	else:
		instance_material = ShaderMaterial.new()
		instance_material.shader = REPLAY_OUTLINE_SHADER
		instance_material.set_shader_parameter("tint_color", Color.WHITE)
		instance_material.set_shader_parameter("outline_color", Color.TRANSPARENT)
		instance_material.set_shader_parameter("outline_size", 0.0)
		default_outline_color = Color.TRANSPARENT
		default_outline_size = 0.0
		default_tint_color = Color.WHITE
	sprite.material = instance_material

# 敵を死亡状態へ遷移させる。
func die() -> void:
	state_machine.change_state(&"Dying", null)

# 攻撃判定に入った相手を死亡させる。
func _on_attack_hitbox_body_entered(body: Node) -> void:
	if not attack_hitbox.monitoring:
		return
	if body.has_method("receive_memory_action_push"):
		body.receive_memory_action_push(self, active_action_record)
		return
	if body.has_method("is_contact_immune_from") and body.is_contact_immune_from(self):
		return
	if body.has_method("die"):
		body.die()
